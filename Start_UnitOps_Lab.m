function master=Start_UnitOps_Lab()
% One central MATLAB command: launches student browser bridge and instructor panel.
% Requires MATLAB, Modbus support (Industrial Communication Toolbox) and Python 3.
root=fileparts(mfilename('fullpath'));
if ~ispc
    error('This classroom launcher currently supports the central Windows PC.');
end
% Start small Python HTTP service (no DAQ / PID logic in Python).
% The bridge binds ONLY to the dedicated lab Ethernet IP.
bridge=fullfile(root,'bridge.py');
% Prevent conflicts with v7 or a second central controller on the same port.
portBusy=false;
try
    probe=tcpclient('192.168.0.200',8088,'ConnectTimeout',1);
    portBusy=true;
    clear probe;
catch
end
if portBusy
    error(['Port 8088 is already in use. Close the previous web app/bridge ' ...
           'and its MATLAB master before launching this version.']);
end
cmd=sprintf('start "UnitOps web bridge" /MIN py -3 "%s" --host 192.168.0.200 --port 8088',bridge);
[status,msg]=system(cmd);
if status~=0
    warning('Browser bridge startup may have failed: %s',msg);
end
master=UnitOpsMaster(root);
assignin('base','UnitOpsLabMaster',master);
fprintf('Instructor MATLAB GUI opened. Student URL: http://192.168.0.200:8088\n');
fprintf('Station codes: %s\n',fullfile(root,'runtime','ACCESS_CODES_FOR_INSTRUCTOR.txt'));
end
