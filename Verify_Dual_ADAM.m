function T = Verify_Dual_ADAM()
% READ-ONLY connectivity and channel check for ADAM-6024 + ADAM-6050.
% Requires MATLAB Industrial Communication Toolbox. No DO writes.
% Configure IPs in Advantech Utility first. The temperature span is provisional.
analogIP='192.168.0.20';
digitalIP='192.168.0.21';
port=502;
fprintf('Connecting ADAM-6024 at %s ...\n',analogIP);
a=modbus('tcpip',analogIP,port);
fprintf('Connecting ADAM-6050 at %s ...\n',digitalIP);
d=modbus('tcpip',digitalIP,port);
station=(1:4)';
AI=(0:3)'; DO=(0:3)';
raw=zeros(4,1); status=zeros(4,1); range=zeros(4,1);
mA=zeros(4,1); temp_C=zeros(4,1); coil=zeros(4,1);
for k=1:4
    raw(k)=double(read(a,'holdingregs',k,1,'uint16'));
    status(k)=double(read(a,'holdingregs',k+20,1,'uint16'));
    range(k)=double(read(a,'holdingregs',k+200,1,'uint16'));
    mA(k)=4+16*raw(k)/65535;
    temp_C(k)=0+(150-0)*raw(k)/65535;
    coil(k)=double(read(d,'coils',16+k,1));
end
T=table(station,AI,DO,raw,range,status,mA,temp_C,coil,...
    'VariableNames',{'Station','AI','DO','Raw','RangeCode','AI_Status','mA','Temp_C_Provisional','DO_Logic'});
disp(T);
if any(range~=7)
    warning('Some analog channels do not show range code 7 (4-20 mA).');
end
if any(status~=0)
    warning('Some analog channels have nonzero diagnostic status (unwired channels will be invalid).');
end
fprintf('DO_Logic is Modbus logic readback, NOT proof of SSR or AC power state.\n');
clear a d;
end
