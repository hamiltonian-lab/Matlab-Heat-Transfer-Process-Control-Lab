'use strict';
const $=id=>document.getElementById(id);
let station=null,tab='simulation',data=null,dirty=false;
const format=(x,d=1)=>x===null||x===undefined||!Number.isFinite(Number(x))?'—':Number(x).toFixed(d);
async function req(path,payload){let opts={cache:'no-store',credentials:'same-origin'};if(payload!==undefined){opts.method='POST';opts.headers={'Content-Type':'application/json'};opts.body=JSON.stringify(payload)}let r=await fetch(path,opts);let j=await r.json();if(!r.ok)throw Error(j.error||`HTTP ${r.status}`);return j}
function showLab(on){$('login-panel').hidden=on;$('lab-panel').hidden=!on;if(on){$('station-heading').textContent='· Station '+station;updateExportLink();}}
async function login(){try{if(!/^[0-9]{6}$/.test($('station-code').value)){ $('login-error').textContent='Enter your 6-digit station code';return;}let r=await req('/api/login',{station:parseInt($('station-choice').value,10),code:$('station-code').value});station=r.station;$('station-code').value='';showLab(true);await refresh()}catch(e){$('login-error').textContent=e.message}}
async function logout(){await req('/api/logout',{});station=null;data=null;showLab(false)}
async function cmd(command,extra={}){try{let res=await req('/api/command',{command,...extra});$('system-message').textContent=res.message||'Command accepted';setTimeout(refresh,450)}catch(e){$('system-message').textContent='Command error: '+e.message}}
async function saveSettings(model){let ids=model?['gain','tau','deadtime','window']:['sp','kp','ki','kd'];let keys=model?['gain','tau','deadtime','window']:['setpoint','kp','ki','kd'];let v={};for(let i=0;i<keys.length;i++)v[keys[i]]=Number($(ids[i]).value);dirty=false;await cmd('settings',{values:v})}
function switchTab(next){tab=next;document.querySelectorAll('.tab').forEach(el=>el.classList.toggle('active',el.dataset.tab===next));$('sim-controls').hidden=next!=='simulation';$('live-controls').hidden=next!=='live';$('tuning-controls').hidden=next!=='tuning';$('model-panel').hidden=next==='live';updateExportLink();render()}
async function refresh(){if(!station)return;try{let r=await req('/api/state');data=r.data;if(data){render()}else{$('bridge-status').textContent='Waiting for MATLAB';$('bridge-status').className='pill';}}catch(e){$('bridge-status').textContent='Disconnected';$('bridge-status').className='pill';$('system-message').textContent=e.message}}
function updateExportLink(){
 const link=$('export-link');
 if(!link) return;
 const mode=(tab==='live')?'live':'simulation';
 link.href='/api/export.csv?mode='+mode;
 link.textContent=(mode==='live')?'Export live experiment CSV':'Export digital twin CSV';
}
function render(){if(!data)return;let s=data;let online=s.engine_online;
 $('bridge-status').textContent=online?'MATLAB online':'MATLAB offline / stale';$('bridge-status').className=online?'pill good':'pill';
 let live=tab==='live'; $('temperature-label').textContent=live?'WIKA TEMPERATURE':'DIGITAL TWIN TEMP';$('temperature').textContent=format(live?s.measured_c:s.sim_temp);$('setpoint-card').textContent=format(s.setpoint);$('duty').textContent=format(live?s.live_duty:s.sim_duty);$('do-state').textContent=(s.do_readback===null||Array.isArray(s.do_readback))?'—':s.do_readback?'ON':'OFF';
 $('duty-label').textContent=live?'REAL PID DUTY':'SIMULATED PID DUTY';
 $('acquisition-note').textContent='ADAM-6024 AI'+s.ai_channel+' · '+(s.live_ok?'Input valid':'Check sensor / DAQ');
 $('readings').textContent='Transmitter current: '+format(s.current_ma,3)+' mA | Control: '+(s.control_mode||'PID')+' | Live PID: '+(s.live_running?'RUNNING':'STOPPED')+' | Twin: '+(s.sim_running?'RUNNING':'PAUSED');
 $('hardware-mode').textContent=(s.output_armed?'Instructor armed DO'+s.output_channel+'. MATLAB PID may command its SSR. ':'DO'+s.output_channel+' is DISARMED; measurements and calculated PID remain available. ')+
   'Instructor software trip: '+format(s.software_trip_c)+' °C. Live setpoint must be below this threshold.';
 if(s.fault)$('system-message').textContent='Controller: '+s.fault;
 else if(!online)$('system-message').textContent='Central MATLAB controller is not updating. Do not interpret displayed values as live.';
 else $('system-message').textContent=s.daq_message+' · '+s.calibration_note;
 $('live-start').disabled=!online||!s.live_ok||!s.live_setpoint_ok||s.live_running;
 $('live-stop').disabled=!online;
 if(!dirty){let mapping={sp:'setpoint',kp:'kp',ki:'ki',kd:'kd',gain:'gain',tau:'tau',deadtime:'deadtime',window:'window'};for(let [id,key] of Object.entries(mapping))if(document.activeElement!==$(id))$(id).value=s[key]}
 const matrix=Array.isArray(s.history)?s.history:[];
 // MATLAB jsonencode of numeric 2D matrix serializes each row as an array.
 let samples=matrix.map(x=>Array.isArray(x)?x:[]).filter(x=>x.length>=8);
 draw('temperature-chart',samples,[{idx:1,c:'#159a8b'},{idx:2,c:'#6087dc'},{idx:3,c:'#c99649'}]);
 draw('pid-chart',samples,[{idx:live?5:4,c:'#159a8b'},
  {idx:live?9:6,c:'#6087dc'},{idx:live?10:7,c:'#c99649'},
  ...(live?[{idx:11,c:'#bd7388'}]:[])]);
}
function draw(id,rows,series){const c=$(id),ctx=c.getContext('2d'),w=c.width,h=c.height;ctx.clearRect(0,0,w,h);ctx.fillStyle='#fff';ctx.fillRect(0,0,w,h);const L=49,R=14,T=13,B=23;
 let pts=rows.slice(-250),values=[];for(let r of pts)for(let e of series){let v=r[e.idx];if(Number.isFinite(v))values.push(v)}let lo=values.length?Math.min(...values):0,hi=values.length?Math.max(...values):100;if(hi-lo<8){lo-=4;hi+=4}else{let gap=(hi-lo)*.13;lo-=gap;hi+=gap}if(!Number.isFinite(lo)||!Number.isFinite(hi)||hi===lo)return;
 ctx.strokeStyle='#e8eef5';ctx.fillStyle='#7d8da3';ctx.lineWidth=1;ctx.font='11px Segoe UI, sans-serif';for(let k=0;k<=4;k++){let y=T+k*(h-T-B)/4;ctx.beginPath();ctx.moveTo(L,y);ctx.lineTo(w-R,y);ctx.stroke();ctx.fillText((hi-(hi-lo)*k/4).toFixed(0),8,y+3)}
 for(let e of series){ctx.beginPath();ctx.lineWidth=2.5;ctx.strokeStyle=e.c;let started=false;for(let i=0;i<pts.length;i++){let v=pts[i][e.idx];if(!Number.isFinite(v)){started=false;continue}let x=L+i*(w-L-R)/Math.max(1,pts.length-1),y=T+(hi-v)/(hi-lo)*(h-T-B);if(!started){ctx.moveTo(x,y);started=true}else{ctx.lineTo(x,y)}}ctx.stroke()}
 ctx.fillStyle='#7d8da3';ctx.fillText('Elapsed samples →',w-122,h-4)}
$('login-btn').onclick=login;$('station-code').addEventListener('keydown',e=>{if(e.key==='Enter')login()});$('logout').onclick=logout;$('apply').onclick=()=>saveSettings(false);$('apply-model').onclick=()=>saveSettings(true);$('sim-start').onclick=()=>cmd('start_sim');$('sim-pause').onclick=()=>cmd('pause_sim');$('sim-reset').onclick=()=>cmd('reset_sim');$('disturb').onclick=()=>cmd('cooling_disturbance');$('live-start').onclick=()=>cmd('start_live');$('live-stop').onclick=()=>cmd('stop_live');$('tune-apply').onclick=()=>cmd('set_tuning',{method:$('method').value});
document.querySelectorAll('.tab').forEach(t=>t.onclick=()=>switchTab(t.dataset.tab));for(let id of ['sp','kp','ki','kd','gain','tau','deadtime','window'])$(id).addEventListener('input',()=>{dirty=true});
(async()=>{try{let a=await req('/api/me');if(a.station){station=a.station;showLab(true);await refresh()}}catch(e){}setInterval(refresh,1200)})();
