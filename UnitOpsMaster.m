classdef UnitOpsMaster < handle
    % Central MATLAB process for a teaching-lab digital twin and web students.
    % MATLAB owns the DAQ, PID loops, simulated vessel and instructor UI.
    % Python bridge.py ONLY serves the web pages and queues JSON commands.
    properties
        Root
        Runtime
        AnalogIP = '192.168.0.20'   % ADAM-6024: AI0..AI3
        DigitalIP = '192.168.0.21'  % ADAM-6050: DO0..DO3 (proposed IP)
        LabIP = '192.168.0.200'
        DAQPort = 502
        Sample_s = 1
        AI_Tmin = [0 0 0 0]         % PROVISIONAL per-channel WIKA Tmin C
        AI_Tmax = [150 150 150 150] % VERIFY each transmitter's actual span.
        SoftwareTrip_C = [60 60 60 60] % Instructor-adjustable per physical station (C)
        OutputArmed = false(1,4)  % Instructor-enable per commissioned station
        Analog = []
        Digital = []
        DigitalReady = false
        LastDigitalAttempt = 0
        DAQMessage = 'Waiting for dual ADAM modules'
        S
        LoopTimer = []
        Figure
        StatusLabel
        StatusTable
        OutputChecks = cell(1,4)
        TripFields = cell(1,4)
        LastTick
        Busy = false
        Closing = false
    end
    methods
        function obj = UnitOpsMaster(root)
            obj.Root = char(root);
            obj.Runtime = fullfile(obj.Root,'runtime');
            if ~exist(obj.Runtime,'dir'),mkdir(obj.Runtime);end
            inbox=fullfile(obj.Runtime,'inbox');
            if ~exist(inbox,'dir'),mkdir(inbox);end
            obj.S = repmat(obj.blankStation(),1,4);
            for i=1:4
                obj.S(i).number=i;
                obj.S(i).ai_channel=i-1;
                obj.S(i).output_channel=16+i; % ADAM-6050 coils 17..20
            end
            obj.makeUI();
            obj.LastTick=tic;
            obj.LoopTimer=timer('ExecutionMode','fixedSpacing','Period',obj.Sample_s, ...
                'BusyMode','drop','TimerFcn',@(~,~)obj.tick(), ...
                'ErrorFcn',@(~,evt)obj.reportError(evt));
            obj.ensureDigitalConnected();
            obj.sendOff();
            obj.publishAll();
            start(obj.LoopTimer);
        end

        function S=blankStation(~)
            S=struct('number',1,'ai_channel',0,'output_channel',NaN, ...
              'setpoint',35,'kp',2,'ki',0.015,'kd',0,'control_mode','PID', ...
              'gain',70,'tau',100,'deadtime',5,'window',20, ...
              'sim_temp',21,'sim_running',false,'sim_seconds',0, ...
              'sim_integral',0,'sim_prev',NaN,'sim_duty',0,'sim_p',0,'sim_i',0,'sim_d',0, ...
              'delay_queue',zeros(1,0), ...
              'measured_c',NaN,'current_ma',NaN,'raw',NaN,'ai_status',NaN,'live_ok',false, ...
              'live_running',false,'live_seconds',0,'live_integral',0,'live_prev',NaN, ...
              'live_duty',0,'live_p',0,'live_i',0,'live_d',0, ...
              'do_request',false,'do_readback',NaN,'fault','', ...
              'cool_disturbance',0,'history',zeros(0,12));
        end

        function makeUI(obj)
            f=uifigure('Name','UnitOps | MATLAB Master | ADAM-6024 + ADAM-6050', ...
                'Position',[60 70 1100 800],'CloseRequestFcn',@(~,~)obj.close());
            obj.Figure=f;
            root=uigridlayout(f,[6 1]);
            % Reserve enough height for the 4 bottom command buttons. A nested
            % grid with MATLAB's default padding/spacing previously exceeded
            % the 154-pixel parent row and clipped the lower button edges.
            root.RowHeight={48,44,36,190,194,'1x'};
            root.Padding=[16 14 16 14];root.RowSpacing=8;
            h=uilabel(root,'Text','Unit Operations | Four-Station MATLAB Controller', ...
                'FontSize',21,'FontWeight','bold');h.Layout.Row=1;
            obj.StatusLabel=uilabel(root,'Text','Connecting...','FontSize',12,'WordWrap','on');
            obj.StatusLabel.Layout.Row=2;
            lab=uilabel(root,'Text', ...
              sprintf('Student URL: http://%s:8088  |  Analog ADAM-6024: %s  |  Digital ADAM-6050: %s', ...
              obj.LabIP,obj.AnalogIP,obj.DigitalIP),'FontSize',12);
            lab.Layout.Row=3;
            obj.StatusTable=uitable(root,'ColumnName', ...
              {'Station','Input','Output','Temp (C)','Setpoint','Simulation','Live PID','SSR demand','Status'}, ...
              'ColumnEditable',false(1,9));
            obj.StatusTable.Layout.Row=4;
            controls=uigridlayout(root,[3 4]);
            controls.ColumnWidth={'1x','1x','1x','1x'};
            controls.Padding=[4 4 4 4];
            controls.RowSpacing=8;
            controls.ColumnSpacing=10;
            controls.RowHeight={46,46,64};
            controls.Layout.Row=5;
            for j=1:4
                % Only the instructor panel can enable a physical output.
                chk=uicheckbox(controls,'Text',sprintf('Arm Station %d hardware',j), ...
                    'Value',false,'ValueChangedFcn',@(~,~)obj.toggleOutput(j));
                chk.Layout.Row=1;chk.Layout.Column=j;
                obj.OutputChecks{j}=chk;
                tripRow=uigridlayout(controls,[1 2]);
                tripRow.ColumnWidth={'1x',86};tripRow.Padding=[0 0 0 0];
                tripRow.Layout.Row=2;tripRow.Layout.Column=j;
                uilabel(tripRow,'Text',sprintf('S%d trip (C)',j));
                fld=uieditfield(tripRow,'numeric','Value',obj.SoftwareTrip_C(j), ...
                    'Limits',[obj.AI_Tmin(j)+1,obj.AI_Tmax(j)], ...
                    'ValueChangedFcn',@(~,~)obj.setSoftwareTrip(j));
                fld.Layout.Column=2;
                obj.TripFields{j}=fld;
            end
            b=uibutton(controls,'Text','STOP ALL / DO0-DO3 OFF', ...
                'FontWeight','bold','ButtonPushedFcn',@(~,~)obj.stopAll());
            b.Layout.Row=3;b.Layout.Column=1;
            b2=uibutton(controls,'Text','Open station access codes', ...
                'ButtonPushedFcn',@(~,~)obj.viewCodes());
            b2.Layout.Row=3;b2.Layout.Column=2;
            b3=uibutton(controls,'Text','STOP + Disarm all stations', ...
                'ButtonPushedFcn',@(~,~)obj.stopAll());
            b3.Layout.Row=3;b3.Layout.Column=3;
            b4=uibutton(controls,'Text','Reconnect digital module', ...
                'ButtonPushedFcn',@(~,~)obj.reconnectDigital());
            b4.Layout.Row=3;b4.Layout.Column=4;
            detail=uilabel(root,'Text', ...
               'Station 1: AI0/DO0 (coil 17) | 2: AI1/DO1 (18) | 3: AI2/DO2 (19) | 4: AI3/DO3 (20).', ...
               'WordWrap','on','FontSize',12);
            detail.Layout.Row=6;
            obj.updateUI();
        end

        function viewCodes(obj)
            p=fullfile(obj.Runtime,'ACCESS_CODES_FOR_INSTRUCTOR.txt');
            if exist(p,'file')
                if ispc,winopen(p); else,edit(p);end
            else
                uialert(obj.Figure, ...
                  'The web bridge has not generated access codes. Check that Python is installed and the bridge is running.', ...
                  'Browser bridge');
            end
        end

        function toggleOutput(obj,i)
            desired=logical(obj.OutputChecks{i}.Value);
            obj.stopLive(i); % Change arming only while station output is OFF.
            if desired
                obj.ensureDigitalConnected();
                if ~obj.DigitalReady
                    obj.OutputChecks{i}.Value=false;
                    obj.OutputArmed(i)=false;
                    uialert(obj.Figure,'ADAM-6050 is not reachable. Check its power/IP.', ...
                        'Output device offline');return;
                end
            end
            obj.OutputArmed(i)=desired;
            if ~desired,obj.sendOff(i);end
            obj.publishAll();obj.updateUI();
        end

        function setSoftwareTrip(obj,i)
            % Instructor-managed software threshold, not a substitute for
            % an independent hardware thermal cutoff.
            newTrip=double(obj.TripFields{i}.Value);
            if ~isfinite(newTrip) || newTrip<=obj.AI_Tmin(i) || newTrip>obj.AI_Tmax(i)
                obj.TripFields{i}.Value=obj.SoftwareTrip_C(i);
                return;
            end
            obj.stopLive(i); % Never change the physical trip during a run.
            obj.SoftwareTrip_C(i)=newTrip;
            obj.publishAll();obj.updateUI();
        end

        function reconnectDigital(obj)
            for j=1:4,obj.stopLive(j);end
            obj.Digital=[];obj.DigitalReady=false;
            obj.LastDigitalAttempt=0;
            obj.ensureDigitalConnected();
            obj.updateUI();
        end

        function ensureDigitalConnected(obj)
            if obj.DigitalReady && ~isempty(obj.Digital),return;end
            now_s=posixtime(datetime('now','TimeZone','UTC'));
            if obj.LastDigitalAttempt>0 && now_s-obj.LastDigitalAttempt<5,return;end
            obj.LastDigitalAttempt=now_s;
            try
                obj.Digital=modbus('tcpip',obj.DigitalIP,obj.DAQPort);
                % Force only the four assigned channels to OFF on connection.
                write(obj.Digital,'coils',17,[0 0 0 0]);
                rb=double(read(obj.Digital,'coils',17,4));
                if any(rb~=0),error('DO0-DO3 did not acknowledge OFF');end
                obj.DigitalReady=true;
                for j=1:4
                    obj.S(j).do_request=false;
                    obj.S(j).do_readback=rb(j);
                    obj.S(j).live_running=false;
                end
                obj.DAQMessage='ADAM-6050 digital module connected; four outputs OFF';
            catch ME
                obj.Digital=[];obj.DigitalReady=false;
                for j=1:4,obj.OutputArmed(j)=false;end
                for j=1:numel(obj.OutputChecks)
                    if ~isempty(obj.OutputChecks{j}) && isvalid(obj.OutputChecks{j})
                        obj.OutputChecks{j}.Value=false;
                    end
                end
                obj.DAQMessage=['ADAM-6050 unavailable: ' ME.message];
            end
        end

        function reportError(obj,evt)
            try
                obj.stopAll();
                obj.DAQMessage=['MATLAB timer error: ' evt.Data.Message];
            catch
            end
        end

        function tick(obj)
            if obj.Busy || obj.Closing,return;end
            obj.Busy=true;
            try
                dt=min(3,max(.2,toc(obj.LastTick)));
                obj.LastTick=tic;
                obj.handleCommands();
                obj.ensureDigitalConnected();
                obj.readADAM();
                for i=1:4
                    s=obj.S(i);
                    if s.sim_running
                        [s,s.sim_duty,s.sim_p,s.sim_i,s.sim_d]=obj.pidStep(s,s.sim_temp,dt,false);
                        q=s.delay_queue;
                        q(end+1)=s.sim_duty;
                        delaySteps=max(0,ceil(s.deadtime/dt));
                        if numel(q)>delaySteps
                            actuation=q(1);q(1)=[];
                        else
                            actuation=0;
                        end
                        s.delay_queue=q;
                        ambient=21;
                        target=ambient+s.gain*actuation/100+s.cool_disturbance;
                        alpha=1-exp(-dt/max(1,s.tau));
                        s.sim_temp=s.sim_temp+alpha*(target-s.sim_temp);
                        s.sim_seconds=s.sim_seconds+dt;
                    end
                    if s.live_running
                        s.live_seconds=s.live_seconds+dt;
                        if ~s.live_ok || ~isfinite(s.measured_c)
                            s.fault='Temperature input invalid or disconnected';
                            obj.S(i)=s;obj.stopLive(i);s=obj.S(i);
                        elseif s.measured_c>=obj.SoftwareTrip_C(i)
                            s.fault=sprintf('Instructor software temperature trip: %.1f C',obj.SoftwareTrip_C(i));
                            obj.S(i)=s;obj.stopLive(i);s=obj.S(i);
                        elseif s.setpoint<obj.AI_Tmin(i) || s.setpoint>=obj.SoftwareTrip_C(i)
                            s.fault='Live setpoint outside instructor-configured physical operating range';
                            obj.S(i)=s;obj.stopLive(i);s=obj.S(i);
                        elseif obj.OutputArmed(i) && ~obj.hasBrowserHeartbeat(i)
                            s.fault='Student browser heartbeat lost';
                            obj.S(i)=s;obj.stopLive(i);s=obj.S(i);
                        else
                            [s,s.live_duty,s.live_p,s.live_i,s.live_d]=obj.pidStep(s,s.measured_c,dt,true);
                            if obj.OutputArmed(i)
                                if ~obj.DigitalReady
                                    error('ADAM-6050 offline while Station %d live',i);
                                end
                                desired=mod(s.live_seconds,s.window) < (s.window*s.live_duty/100);
                                if desired~=s.do_request
                                    s.do_readback=obj.commandDO(i,desired);
                                    s.do_request=desired;
                                end
                            end
                        end
                    end
                    % Keep a bounded history for charts and CSV exports.
                    row=[s.sim_seconds,s.sim_temp,s.measured_c,s.setpoint, ...
                         s.sim_duty,s.live_duty,s.sim_p,s.sim_i,s.live_seconds, ...
                         s.live_p,s.live_i,s.live_d];
                    s.history(end+1,:)=row;
                    if size(s.history,1)>400,s.history=s.history(end-399:end,:);end
                    obj.S(i)=s;
                end
                obj.publishAll();
                obj.updateUI();
            catch ME
                obj.DAQMessage=['Controller fault: ' ME.message];
                obj.stopAll();
                try,obj.publishAll();catch,end
                try,obj.updateUI();catch,end
            end
            obj.Busy=false;
        end

        function [s,duty,p,iTerm,dTerm]=pidStep(obj,s,temp,dt,isLive)
            if isLive
                integ=s.live_integral;prev=s.live_prev;
            else
                integ=s.sim_integral;prev=s.sim_prev;
            end
            err=s.setpoint-temp;
            slope=0;
            if isfinite(prev),slope=(temp-prev)/max(dt,.01);end
            kp=s.kp;ki=s.ki;kd=s.kd;
            if strcmp(s.control_mode,'Fuzzy PID')
                [fP,fI,fD]=obj.fuzzyGainMultipliers(err,-slope);
                kp=kp*fP;ki=ki*fI;kd=kd*fD;
            end
            candidate=integ+err*dt;
            unbounded=kp*err+ki*candidate-kd*slope;
            if ~((unbounded>100 && err>0)||(unbounded<0 && err<0))
                integ=candidate;
            end
            p=kp*err;iTerm=ki*integ;dTerm=-kd*slope;
            duty=min(100,max(0,p+iTerm+dTerm));
            if isLive,s.live_integral=integ;s.live_prev=temp;
            else,s.sim_integral=integ;s.sim_prev=temp;end
        end

        function [mP,mI,mD]=fuzzyGainMultipliers(~,e,de)
            % Lightweight 3x3 zero-order Sugeno rule-base supervisor.
            % Educational example only: NOT a trained ML model.
            en=max(-1,min(1,e/10));
            dn=max(-1,min(1,de/0.25));
            muE=[max(0,-en),max(0,1-abs(en)),max(0,en)];
            muD=[max(0,-dn),max(0,1-abs(dn)),max(0,dn)];
            weights=muE.'*muD;
            pRules=[1.6 1.4 1.15; 1.15 0.85 1.15; 1.15 1.4 1.6];
            iRules=[0.4 0.6 0.75; 0.8 1.0 0.8; 0.75 0.6 0.4];
            dRules=[1.1 1.25 1.5; 1.4 1.0 1.4; 1.5 1.25 1.1];
            den=max(eps,sum(weights,'all'));
            mP=sum(weights.*pRules,'all')/den;
            mI=sum(weights.*iRules,'all')/den;
            mD=sum(weights.*dRules,'all')/den;
        end

        function readADAM(obj)
            if isempty(obj.Analog)
                try
                    obj.Analog=modbus('tcpip',obj.AnalogIP,obj.DAQPort);
                    obj.DAQMessage='Connected to ADAM-6024 analog module';
                catch ME
                    obj.DAQMessage=['ADAM-6024 unavailable: ' ME.message];
                    obj.markInputBad();return;
                end
            end
            for k=1:4
                s=obj.S(k);
                try
                    rangeCode=double(read(obj.Analog,'holdingregs',200+k,1,'uint16'));
                    raw=double(read(obj.Analog,'holdingregs',k,1,'uint16'));
                    status=double(read(obj.Analog,'holdingregs',20+k,1,'uint16'));
                    s.raw=raw;s.ai_status=status;
                    s.current_ma=4+16*(raw/65535);
                    s.measured_c=obj.AI_Tmin(k)+(obj.AI_Tmax(k)-obj.AI_Tmin(k))*(raw/65535);
                    s.live_ok=rangeCode==7 && status==0 && isfinite(s.measured_c);
                    if ~s.live_ok
                        s.fault=sprintf('AI%d invalid: range=%d status=%d',k-1,rangeCode,status);
                    end
                catch ME
                    s.live_ok=false;s.measured_c=NaN;s.ai_status=NaN;
                    obj.DAQMessage=['ADAM-6024 read failed: ' ME.message];
                    obj.Analog=[];
                end
                obj.S(k)=s;
                if isempty(obj.Analog)
                    obj.markInputBad();break;
                end
            end
        end

        function markInputBad(obj)
            for i=1:4
                obj.S(i).live_ok=false;
                obj.S(i).ai_status=NaN;
                obj.S(i).measured_c=NaN;
            end
        end

        function check=commandDO(obj,i,on)
            if ~obj.DigitalReady || isempty(obj.Digital)
                error('ADAM-6050 disconnected: no output command possible.');
            end
            if i<1 || i>4 || i~=floor(i),error('Invalid station number');end
            addr=obj.S(i).output_channel;
            try
                write(obj.Digital,'coils',addr,double(logical(on)));
                check=double(read(obj.Digital,'coils',addr,1));
                if check~=double(logical(on))
                    error('Station %d DO%d logic readback mismatch',i,i-1);
                end
            catch ME
                obj.DigitalReady=false;
                obj.Digital=[];
                obj.OutputArmed(:)=false;
                error('ADAM-6050 output fault station %d: %s',i,ME.message);
            end
        end

        function sendOff(obj,i)
            % OFF command only; NEVER assume this electrically removes AC power.
            if nargin<2,stations=1:4;else,stations=i;end
            for j=stations
                try
                    if obj.DigitalReady && ~isempty(obj.Digital)
                        write(obj.Digital,'coils',obj.S(j).output_channel,0);
                        rb=double(read(obj.Digital,'coils',obj.S(j).output_channel,1));
                        if rb~=0,error('OFF readback mismatch');end
                        obj.S(j).do_readback=rb;
                    end
                catch ME
                    obj.DigitalReady=false;obj.Digital=[];
                    obj.DAQMessage=sprintf('DO%d OFF request failed: %s. Use physical disconnect!',j-1,ME.message);
                end
                obj.S(j).do_request=false;
                if ~obj.DigitalReady,obj.S(j).do_readback=NaN;end
            end
        end

        function stopLive(obj,i)
            s=obj.S(i);s.live_running=false;s.live_duty=0;
            s.do_request=false;
            obj.S(i)=s;
            obj.sendOff(i);
        end

        function stopAll(obj)
            for j=1:4
                obj.S(j).sim_running=false;
                obj.S(j).live_running=false;
                obj.S(j).live_duty=0;
                obj.OutputArmed(j)=false;
                if j<=numel(obj.OutputChecks) && ~isempty(obj.OutputChecks{j}) ...
                        && isvalid(obj.OutputChecks{j})
                    obj.OutputChecks{j}.Value=false;
                end
            end
            obj.sendOff();
            try,obj.publishAll();catch,end
            try,obj.updateUI();catch,end
        end

        function yes=hasBrowserHeartbeat(obj,i)
            path=fullfile(obj.Runtime,sprintf('heartbeat%d.txt',i));
            yes=false;
            try
                v=str2double(strtrim(fileread(path)));
                yes=isfinite(v) && abs(posixtime(datetime('now','TimeZone','UTC'))-v)<10;
            catch
            end
        end

        function handleCommands(obj)
            files=dir(fullfile(obj.Runtime,'inbox','*.json'));
            for k=1:min(40,numel(files))
                path=fullfile(files(k).folder,files(k).name);
                try
                    cmd=jsondecode(fileread(path));
                    delete(path);
                    if abs(posixtime(datetime('now','TimeZone','UTC'))-double(cmd.at_epoch))>6
                        continue; % refuse old queued commands on restart
                    end
                    i=double(cmd.station);
                    if i<1 || i>4 || i~=floor(i),continue;end
                    s=obj.S(i);
                    switch char(cmd.command)
                        case 'settings'
                            values=cmd.values;
                            fields=fieldnames(values);
                            for n=1:numel(fields)
                                f=fields{n};v=double(values.(f));
                                if isfield(s,f)&&isfinite(v)
                                    switch f
                                        case 'setpoint',valid=true; % Live mode checked separately against trip
                                        case 'kp',valid=v>=0;
                                        case 'ki',valid=v>=0;
                                        case 'kd',valid=v>=0;
                                        case 'gain',valid=v>0;
                                        case 'tau',valid=v>0;
                                        case 'deadtime',valid=v>=0;
                                        case 'window',valid=v>=4&&v<=120; % Physical SSR cycle-time engineering constraint
                                        otherwise,valid=false;
                                    end
                                    if valid,s.(f)=v;end
                                end
                            end
                        case 'start_sim'
                            s.sim_running=true;
                        case 'pause_sim'
                            s.sim_running=false;
                        case 'reset_sim'
                            s.sim_running=false;s.sim_temp=21;s.sim_seconds=0;
                            s.sim_integral=0;s.sim_prev=NaN;s.delay_queue=[];s.history=zeros(0,12);
                        case 'cooling_disturbance'
                            if s.cool_disturbance==0,s.cool_disturbance=-12;
                            else,s.cool_disturbance=0;end
                        case 'start_live'
                            if s.live_ok && s.measured_c<obj.SoftwareTrip_C(i) ...
                                    && s.setpoint>=obj.AI_Tmin(i) && s.setpoint<obj.SoftwareTrip_C(i)
                                obj.S(i)=s;obj.stopLive(i);s=obj.S(i);
                                s.live_running=true;s.live_seconds=0;
                                s.live_integral=0;s.live_prev=NaN;s.fault='';
                            else
                                s.fault=sprintf('Cannot start live: verify AI and setpoint below S%d trip (%.1f C)', ...
                                    i,obj.SoftwareTrip_C(i));
                            end
                        case 'stop_live'
                            obj.S(i)=s;obj.stopLive(i);s=obj.S(i);
                        case 'set_tuning'
                            if strcmp(char(cmd.method),'fuzzy')
                                s.control_mode='Fuzzy PID';
                            else
                                [kp,ki,kd]=obj.tuning(s,char(cmd.method));
                                if all(isfinite([kp ki kd]))&&kp>=0&&ki>=0&&kd>=0
                                    s.kp=kp;s.ki=ki;s.kd=kd;
                                    s.control_mode='PID';
                                else
                                    s.fault='Tuning recommendation is non-finite or uses negative PID gains';
                                end
                            end
                    end
                    obj.S(i)=s;
                catch ME
                    try,delete(path);catch,end
                    obj.DAQMessage=['Command error: ' ME.message];
                end
            end
        end

        function [kp,ki,kd]=tuning(~,s,method)
            K=s.gain/100;T=s.tau;L=max(1,s.deadtime);
            switch method
                case 'zn_pi'
                    kp=.9*T/(K*L);ki=kp/(3*L);kd=0;
                case 'zn_pid'
                    kp=1.2*T/(K*L);ki=kp/(2*L);kd=kp*L/2;
                case 'imc_pi'
                    lambda=max(T/2,L);kp=T/(K*(lambda+L));
                    Ti=min(T,4*(lambda+L));ki=kp/Ti;kd=0;
                otherwise
                    kp=s.kp;ki=s.ki;kd=s.kd;
            end
        end

        function publishAll(obj)
            epoch=posixtime(datetime('now','TimeZone','UTC'));
            for i=1:4
                s=obj.S(i);
                if isnan(s.do_readback),readback=[];
                else,readback=s.do_readback;end
                if isnan(s.measured_c),measured=[];else,measured=s.measured_c;end
                if isnan(s.current_ma),ma=[];else,ma=s.current_ma;end
                data=struct('timestamp_epoch',epoch,'number',i,'setpoint',s.setpoint, ...
                  'kp',s.kp,'ki',s.ki,'kd',s.kd,'control_mode',s.control_mode,'gain',s.gain,'tau',s.tau, ...
                  'deadtime',s.deadtime,'window',s.window, ...
                  'sim_temp',s.sim_temp,'sim_running',s.sim_running, ...
                  'sim_duty',s.sim_duty,'sim_p',s.sim_p,'sim_i',s.sim_i,'sim_d',s.sim_d, ...
                  'measured_c',measured,'current_ma',ma,'ai_status',s.ai_status, ...
                  'live_ok',s.live_ok,'live_running',s.live_running, ...
                  'live_duty',s.live_duty,'live_p',s.live_p,'live_i',s.live_i,'live_d',s.live_d, ...
                  'ai_channel',s.ai_channel,'output_channel',i-1,'do_readback',readback, ...
                  'do_request',s.do_request,'output_armed',obj.OutputArmed(i), ...
                  'fault',s.fault,'daq_message',obj.DAQMessage, ...
                  'software_trip_c',obj.SoftwareTrip_C(i), ...
                  'live_setpoint_ok',s.setpoint>=obj.AI_Tmin(i) && s.setpoint<obj.SoftwareTrip_C(i), ...
                  'calibration_note',sprintf('Transmitter AI%d span %.1f to %.1f C is provisional',i-1,obj.AI_Tmin(i),obj.AI_Tmax(i)), ...
                  'cool_disturbance',s.cool_disturbance, ...
                  'history',s.history);
                obj.writeJSON(fullfile(obj.Runtime,sprintf('station%d.json',i)),data);
                obj.writeCSV(i,s.history);
            end
        end

        function writeJSON(~,path,v)
            tmp=[path '.part'];
            fid=fopen(tmp,'w');
            if fid<0,error('Cannot write status file');end
            c=onCleanup(@()fclose(fid));
            fwrite(fid,jsonencode(v),'char');
            clear c;
            [ok,err]=movefile(tmp,path,'f');
            if ~ok,error('Status file replace failed: %s',err);end
        end

        function writeCSV(obj,i,h)
            obj.writeOneCSV(fullfile(obj.Runtime,sprintf('station%d_history.csv',i)), ...
                'SimulationElapsed_s,DigitalTwin_C,Measured_C,Setpoint_C,SimPID_Duty_pct,LivePID_Duty_pct,SimP_pct,SimI_pct,LiveElapsed_s,LiveP_pct,LiveI_pct,LiveD_pct',h);
            if isempty(h)
                sim=[];live=[];
            else
                sim=h(:,[1 2 4 5 7 8]);
                live=h(:,[9 3 4 6 10 11 12]);
            end
            obj.writeOneCSV(fullfile(obj.Runtime,sprintf('station%d_simulation.csv',i)), ...
                'SimulationElapsed_s,DigitalTwin_C,Setpoint_C,SimPID_Duty_pct,SimP_pct,SimI_pct',sim);
            obj.writeOneCSV(fullfile(obj.Runtime,sprintf('station%d_live.csv',i)), ...
                'LiveElapsed_s,Measured_C,Setpoint_C,LivePID_Duty_pct,LiveP_pct,LiveI_pct,LiveD_pct',live);
        end

        function writeOneCSV(~,p,header,h)
            tmp=[p '.part'];
            fid=fopen(tmp,'w');
            if fid<0,return;end
            c=onCleanup(@()fclose(fid));
            fprintf(fid,'%s\n',header);
            if ~isempty(h)
                cols=size(h,2);
                fmt=[repmat('%.6g,',1,cols-1) '%.6g\n'];
                fprintf(fid,fmt,h.');
            end
            clear c;
            movefile(tmp,p,'f');
        end

        function updateUI(obj)
            if isempty(obj.Figure)||~isvalid(obj.Figure),return;end
            displayData=cell(4,9);
            for i=1:4
                s=obj.S(i);
                displayData(i,:)={i,sprintf('AI%d',s.ai_channel), ...
                  sprintf('DO%d',i-1),obj.displayNum(s.measured_c), ...
                  sprintf('%.1f C',s.setpoint),obj.yesNo(s.sim_running), ...
                  obj.yesNo(s.live_running),obj.yesNo(s.do_request),s.fault};
            end
            obj.StatusTable.Data=displayData;
            obj.StatusLabel.Text=sprintf('ADAM-6024: %s | ADAM-6050 online: %s | Physical arms: [%d %d %d %d]', ...
                obj.DAQMessage,obj.yesNo(obj.DigitalReady),obj.OutputArmed);
        end

        function r=yesNo(~,v)
            if v,r='ON';else,r='OFF';end
        end
        function r=displayNum(~,x)
            if isfinite(x),r=sprintf('%.2f C',x);else,r='--';end
        end

        function close(obj)
            if obj.Closing,return;end
            obj.Closing=true;
            try,stop(obj.LoopTimer);delete(obj.LoopTimer);catch,end
            obj.stopAll();
            try,delete(obj.Figure);catch,end
        end
    end
end
