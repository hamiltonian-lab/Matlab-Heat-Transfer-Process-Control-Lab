"""Transport only: MATLAB owns acquisition, simulation, PID and any Modbus output.
Python stdlib HTTP server for student browsers on an isolated local LAN.
"""
import argparse, csv, io, json, math, os, pathlib, secrets, threading, time, uuid
from http import HTTPStatus
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

ROOT = pathlib.Path(__file__).resolve().parent
RUNTIME = ROOT / 'runtime'
WWW = ROOT / 'www'
RUNTIME.mkdir(exist_ok=True)
COMMANDS = RUNTIME / 'inbox'
COMMANDS.mkdir(exist_ok=True)
CODES = RUNTIME / 'access_codes.json'
LOCK = threading.Lock()
SESSIONS = {}


def atomic_json(path, obj):
    tmp = path.with_name(path.name + '.' + uuid.uuid4().hex + '.tmp')
    tmp.write_text(json.dumps(obj, separators=(',', ':')), encoding='utf-8')
    os.replace(tmp, path)


def load_codes():
    # Four different 6-digit numeric student codes. Preserve valid existing codes
    # across restarts; automatically replace older long/alphanumeric codes.
    codes = None
    if CODES.exists():
        try:
            candidate = json.loads(CODES.read_text(encoding='utf-8'))
            values = [candidate['station'+str(i)] for i in range(1, 5)]
            if (all(isinstance(v, str) and len(v) == 6 and v.isascii() and v.isdigit()
                    for v in values) and len(set(values)) == 4):
                codes = candidate
        except (OSError, ValueError, TypeError, KeyError):
            pass
    if codes is None:
        selected = set()
        while len(selected) < 4:
            selected.add(f'{secrets.randbelow(900000) + 100000:06d}')
        codes = {'station'+str(i): code for i, code in enumerate(sorted(selected), 1)}
        atomic_json(CODES, codes)
    # Never return codes over HTTP; local instructor can view this file.
    (RUNTIME / 'ACCESS_CODES_FOR_INSTRUCTOR.txt').write_text(
        'Local classroom access codes (keep on central PC)\n\n' +
        '\n'.join(f'Station {i}: {codes["station"+str(i)]}' for i in range(1,5)) + '\n',
        encoding='utf-8')
    return codes

CREDENTIALS = load_codes()

class Handler(BaseHTTPRequestHandler):
    server_version = 'UnitOpsLocalBridge/1.0'
    def log_message(self, fmt, *args):
        # Hide cookies; avoid filling command window with polling output
        if not (self.path.startswith('/api/state') and args and str(args[1] if len(args)>1 else '') == '200'):
            super().log_message(fmt, *args)

    def send_json(self, obj, status=200, cookie=None):
        b = json.dumps(obj, allow_nan=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(b)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('X-Frame-Options', 'DENY')
        if cookie:
            self.send_header('Set-Cookie', cookie)
        self.end_headers()
        self.wfile.write(b)

    def auth(self):
        try:
            c=SimpleCookie(); c.load(self.headers.get('Cookie', ''))
            sid=c.get('lab_session').value if c.get('lab_session') else ''
            with LOCK:
                data=SESSIONS.get(sid)
            if data and data['until'] > time.time():
                return data
        except Exception:
            pass
        return None

    def read_body(self):
        n=int(self.headers.get('Content-Length', '0'))
        if n < 1 or n > 8192:
            raise ValueError('Invalid payload length')
        data=json.loads(self.rfile.read(n))
        if not isinstance(data, dict):
            raise ValueError('Expected JSON object')
        return data

    def do_GET(self):
        parsed=urlparse(self.path)
        path=parsed.path
        query=parse_qs(parsed.query)
        if path=='/api/health':
            self.send_json({'server':'ready','engine':'MATLAB owns control; this is HTTP transport only'})
            return
        if path=='/api/state':
            auth=self.auth()
            if not auth:
                self.send_json({'error':'Sign in with the station code'}, 401);return
            filename=RUNTIME / f'station{auth["station"]}.json'
            try:
                v=json.loads(filename.read_text(encoding='utf-8'))
                # Never misrepresent an old measurement as live
                age=time.time()-float(v.get('timestamp_epoch', 0))
                v['engine_online'] = bool(-5 < age < 6)
                v['age_s'] = round(max(0, age), 1)
                # Browser poll doubles as a short-lived student heartbeat for MATLAB.
                (RUNTIME / f'heartbeat{auth["station"]}.txt').write_text(str(time.time()),encoding='utf-8')
                self.send_json({'station':auth['station'],'data':v})
            except (OSError,ValueError,TypeError):
                self.send_json({'station':auth['station'],'data':None,'error':'Waiting for MATLAB master'})
            return
        if path=='/api/me':
            auth=self.auth();self.send_json({'station':auth['station'] if auth else None});return
        if path=='/api/export.csv':
            auth=self.auth()
            if not auth:
                self.send_json({'error':'Sign in first'},401);return
            mode=str(query.get('mode',['combined'])[0]).lower()
            if mode=='simulation':
                file=RUNTIME / f'station{auth["station"]}_simulation.csv'
                download=f'station{auth["station"]}_simulation.csv'
            elif mode=='live':
                file=RUNTIME / f'station{auth["station"]}_live.csv'
                download=f'station{auth["station"]}_live.csv'
            else:
                file=RUNTIME / f'station{auth["station"]}_history.csv'
                download=f'station{auth["station"]}_data.csv'
            try:
                b=file.read_bytes()
            except OSError:
                self.send_json({'error':'No data exported yet'},404);return
            self.send_response(200)
            self.send_header('Content-Type','text/csv')
            self.send_header('Content-Disposition',f'attachment; filename="{download}"')
            self.send_header('Content-Length',str(len(b)))
            self.send_header('Cache-Control','no-store')
            self.end_headers();self.wfile.write(b)
            return
        files={'/':'index.html','/index.html':'index.html','/style.css':'style.css','/app.js':'app.js'}
        name=files.get(path)
        if not name:
            self.send_error(404);return
        media={'index.html':'text/html; charset=utf-8','style.css':'text/css; charset=utf-8','app.js':'text/javascript; charset=utf-8'}[name]
        p=WWW / name
        try:b=p.read_bytes()
        except OSError:
            self.send_error(404);return
        self.send_response(200)
        self.send_header('Content-Type',media)
        self.send_header('Content-Length',str(len(b)))
        self.send_header('Cache-Control','no-cache')
        self.send_header('X-Content-Type-Options','nosniff')
        self.end_headers();self.wfile.write(b)

    def do_POST(self):
        path=urlparse(self.path).path
        try:
            data=self.read_body()
            if path=='/api/login':
                station=int(data.get('station',0));code=data.get('code','')
                if station not in (1,2,3,4) or not secrets.compare_digest(str(code),str(CREDENTIALS['station'+str(station)])):
                    self.send_json({'error':'Incorrect station or code'},403);return
                tok=secrets.token_urlsafe(36)
                with LOCK:
                    SESSIONS[tok]={'station':station,'until':time.time()+3600*6}
                self.send_json({'ok':True,'station':station},cookie=f'lab_session={tok}; HttpOnly; SameSite=Strict; Path=/; Max-Age=21600')
                return
            if path=='/api/logout':
                self.send_json({'ok':True},cookie='lab_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0');return
            if path!='/api/command':
                self.send_json({'error':'Unknown endpoint'},404);return
            sess=self.auth()
            if not sess:
                self.send_json({'error':'Login required'},401);return
            cmd=str(data.get('command',''))
            allowed={'settings','start_sim','pause_sim','reset_sim','start_live','stop_live','set_tuning','cooling_disturbance'}
            if cmd not in allowed:
                self.send_json({'error':'Unsupported command'},400);return
            # Browser has no station override: server decides from the session.
            payload={'station':sess['station'],'command':cmd,'at_epoch':time.time(),'id':uuid.uuid4().hex}
            if cmd=='settings':
                # The browser does not impose fixed simulation setpoint/PID ceilings.
                # MATLAB independently enforces the instructor's physical live trip.
                permitted={'setpoint':(None,None),'kp':(0,None),'ki':(0,None),'kd':(0,None),
                           'gain':(0,None),'tau':(0,None),'deadtime':(0,None),'window':(4,120)}
                vals={}
                for key,value in data.get('values',{}).items():
                    if key not in permitted: raise ValueError('Unknown setting '+str(key))
                    x=float(value)
                    lo,hi=permitted[key]
                    if (not math.isfinite(x) or (lo is not None and x<lo) or
                            (hi is not None and x>hi) or (key in ('gain','tau') and x==0)):
                        raise ValueError('Invalid setting '+key)
                    vals[key]=x
                payload['values']=vals
            if cmd=='set_tuning':
                method=data.get('method')
                if method not in ('zn_pi','zn_pid','imc_pi','manual','fuzzy'):
                    raise ValueError('Unknown tuning method')
                payload['method']=method
            atomic_json(COMMANDS/(payload['id']+'.json'),payload)
            self.send_json({'queued':True,'message':'Command delivered to MATLAB inbox; wait for status'})
        except (ValueError,TypeError,json.JSONDecodeError) as exc:
            self.send_json({'error':str(exc)},400)


def main():
    a=argparse.ArgumentParser()
    a.add_argument('--host',default='192.168.0.200');a.add_argument('--port',type=int,default=8088)
    opt=a.parse_args()
    server=ThreadingHTTPServer((opt.host,opt.port),Handler)
    print(f'Browser bridge running at http://{opt.host}:{opt.port} (no Modbus in Python)',flush=True)
    server.serve_forever(poll_interval=.25)

if __name__=='__main__':main()
