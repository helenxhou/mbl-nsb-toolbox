function gdspk = selspk_trace(spk,dat,tt)
% SELSPKTRACE - Interactive posthoc spike classification
%    gdspk = SELSPKTRACE(spk,dat,tt) starts user interaction for selecting
%    spikes based on previous DETECTSPIKE output SPK.
%    gdspk = SELSPKTRACE(dat,tt) calls DETECTSPIKE internally with standard
%    parameters.
%    gdspk = SELSPKTRACE(spk) does not plot a trace.
%
%    Place the green and blue lines around the relevant dots (it does not
%    matter which one is above and which one is below). More handles
%    can be made by dragging the line; handles can be removed by dragging
%    them past the next handle.

if nargin==1
  dat=[];
  tt=[];
elseif nargin==2
  tt = dat;
  dat = spk;
  dt = mean(diff(tt)/1.0);
  [b,a] = butterhigh1(dt);
  flt = filtfilt(b,a,dat);
  spk = detectspike(flt,tt);
  idx = round((spk.tms-tt(1))./dt)+1;
  spk.amp = dat(idx);
end

global phsc_data

[w,h]=screensize;
figw = w-40;
figh = h-80;
f=figure('units','pixels', 'position',[20 40 figw figh], ...
    'menu', 'none', 'numbertitle', 'off', ...
    'name', 'Posthoc_SpikeClass');
f = double(f);

phsc_data{f}.loaded=0;
phsc_data{f}.figw = figw;
phsc_data{f}.figh = figh;

butw=90;

uicontrol('string','Done', ...
    'position',[10 figh-30 butw 25], ... 
    'style', 'pushbutton',...
    'callback', @phsc_done);

uicontrol('string','Zoom', ...
    'position',[figw-butw-10,figh-30 butw 25], ...
    'tag','zoom', 'style','checkbox', 'value',1);

phsc_data{f}.axesw = figw-60;
phsc_data{f}.axesh = figh-90;
axes('units','pixels', ...
    'position',[55 45 phsc_data{f}.axesw phsc_data{f}.axesh],...
    'tag','graph', 'buttondownfcn',@phsc_click);
hold on
plot(tt,dat,'c','tag','trace','buttondownfcn',@phsc_click);
plot(spk.tms,spk.amp,'b.','tag','spikes','buttondownfcn',@phsc_click);
xlabel 'Time (s)'
ylabel 'V_m (mV)'
plot([0 0],[0 0],'b','linew',2,'tag','lowerline','buttondownfcn',@phsc_click);
plot(0,0,'b.','markersi',20,'tag','lowerdots','buttondownfcn',@phsc_click);
plot([0 0],[0 0],'g','linew',2,'tag','upperline','buttondownfcn',@phsc_click);
plot(0,0,'g.','markersi',20,'tag','upperdots','buttondownfcn',@phsc_click);

a=axis;
setappdata(f,'axlim0',a);
setappdata(f,'axlim',a);

phsc_loaddat(f,spk);
setappdata(f,'completed',0)

while 1
  uiwait(f);
  cancel=0;
  done=0;
  try
    done=getappdata(f,'completed');
  catch
    cancel=1;
  end
  if done | cancel
    break
  end
end

if done
  gdspk = phsc_getdata(f);
  close(f);
else
  gdspk.tms=[];
  gdspk.amp=[];
end


%----------------------------------------------------------------------
function phsc_loaddat(figh,spk)
global phsc_data
figh = double(figh);

phsc_data{figh}.ifn = 'data';
phsc_data{figh}.src.spk.tms = spk.tms;
phsc_data{figh}.src.spk.chs = 1+0*spk.tms;
phsc_data{figh}.src.spk.hei = spk.amp;

phsc_data{figh}.src.type = 'spikes';

phsc_process_spikes(figh);

%----------------------------------------------------------------------
function phsc_process_spikes(figh)
global phsc_data
figh = double(figh);
phsc_data{figh}.loaded = 1;
phsc_data{figh}.c = 1;
switch phsc_data{figh}.src.type
  case 'spikes'
    phsc_data{figh}.C = 1;
    phsc_data{figh}.T = max([max(phsc_data{figh}.src.spk.tms) 1]);
    h = findobj(figh,'tag','trace');
    if ~isempty(h)
      xd = get(h,'xdata');
      phsc_data{figh}.T = 2*xd(end) - xd(end-1);
    end
  case 'histo'
    phsc_data{figh}.C = size(phsc_data{figh}.src.hst,3);
    phsc_data{figh}.T = size(phsc_data{figh}.src.hst,2);
end

phsc_data{figh}.lower_thr = cell(1,phsc_data{figh}.C);
phsc_data{figh}.upper_thr = cell(1,phsc_data{figh}.C);
if isfield(phsc_data{figh}.src,'chnames')
  phsc_data{figh}.chnames = phsc_data{figh}.src.chnames;
else
  phsc_data{figh}.chnames = cell(1,phsc_data{figh}.C);
end

dT = min(60,phsc_data{figh}.T/2);

for c=1:phsc_data{figh}.C
  phsc_data{figh}.lower_thr{c} = [dT 10];
  phsc_data{figh}.upper_thr{c} = [dT 15];
end

delete(findobj(figh,'tag','channelselect'));

figure(figh);
for c=1:phsc_data{figh}.C
  h=uicontrol('string',sprintf('Ch%i %s',c,phsc_data{figh}.chnames{c}),...
      'style','pushbutton',...
      'tag','channelselect','userdata',c,...
      'position',[500+c*75 phsc_data{figh}.figh-30 70 25],...
      'callback',@phsc_channelselect);
  if c==phsc_data{figh}.c
    set(h,'fontweight','bold');
  end
end

set(figh,'name',sprintf('Posthoc_SpikeClass: %s',phsc_data{figh}.ifn));

h = findobj(figh,'tag','trace');
if ~isempty(h)
  yd = get(h,'ydata');
  Y = max(abs(yd))*1.1;
else
  h = findobj(figh,'tag','spikes');
  if ~isempty(h)
    yd = get(h,'ydata');
    Y  = max(abs(yd))*1.1;
  else
    Y = 100;
  end
end
setappdata(figh,'axlim0',[0 phsc_data{figh}.T -Y Y]);
setappdata(figh,'axlim',[0 phsc_data{figh}.T -Y Y]);

phsc_redraw(figh,1);


%----------------------------------------------------------------------
function phsc_redraw(figh,graphtoo)
global phsc_data
figh = double(figh);

axes(findobj(figh,'tag','graph'));
a=getappdata(figh,'axlim');
axis(a);

if graphtoo
end

a=axis;
c=phsc_data{figh}.c;
xx = phsc_data{figh}.lower_thr{c}(:,1);
yy = phsc_data{figh}.lower_thr{c}(:,2);
h = findobj(gca,'tag','lowerdots');
set(h,'xdata',xx, 'ydata',yy);
h = findobj(gca,'tag','lowerline');
set(h,'xdata',[a(1); xx; a(2)], 'ydata',[yy(1); yy; yy(end)]);

xx = phsc_data{figh}.upper_thr{c}(:,1);
yy = phsc_data{figh}.upper_thr{c}(:,2);
h = findobj(gca,'tag','upperdots');
set(h,'xdata',xx, 'ydata',yy);
h = findobj(gca,'tag','upperline');
set(h,'xdata',[a(1); xx; a(2)], 'ydata',[yy(1); yy; yy(end)]);


%----------------------------------------------------------------------
function phsc_click(h,x)
global phsc_data
figh=double(gcbf);

iszoom = get(findobj(figh,'tag','zoom'),'value');


c=phsc_data{figh}.c;
tag=get(h,'tag');
act=0;
switch tag
  case 'lowerdots'
    xx = phsc_data{figh}.lower_thr{c}(:,1);
    yy = phsc_data{figh}.lower_thr{c}(:,2);
    xy=get(gca,'currentpoint'); xy = xy(1,1:2);
    [dd,ii] = min((xy(1)-xx).^2 + (xy(2)-yy).^2);
    mousemove(@phsc_move,'lower',xx,yy,ii);
    act=1;
  case 'lowerline'
    xx = phsc_data{figh}.lower_thr{c}(:,1);
    yy = phsc_data{figh}.lower_thr{c}(:,2);
    xy=get(gca,'currentpoint'); xy = xy(1,1:2);
    ii = findfirst_ge(xx,xy(1));
    if ii>0
      xx=[xx(1:ii-1); xy(1); xx(ii:end)];
      yy=[yy(1:ii-1); xy(2); yy(ii:end)];
    else
      xx=[xx; xy(1)];
      yy=[yy; xy(2)];
      ii=length(xx);
    end
    mousemove(@phsc_move,'lower',xx,yy,ii);
    act=1;
  case 'upperdots'
    xx = phsc_data{figh}.upper_thr{c}(:,1);
    yy = phsc_data{figh}.upper_thr{c}(:,2);
    xy=get(gca,'currentpoint'); xy = xy(1,1:2);
    [dd,ii] = min((xy(1)-xx).^2 + (xy(2)-yy).^2);
    mousemove(@phsc_move,'upper',xx,yy,ii);
    act=1;
  case 'upperline'
    xx = phsc_data{figh}.upper_thr{c}(:,1);
    yy = phsc_data{figh}.upper_thr{c}(:,2);
    xy=get(gca,'currentpoint'); xy = xy(1,1:2);
    ii = findfirst_ge(xx,xy(1));
    if ii>0
      xx=[xx(1:ii-1); xy(1); xx(ii:end)];
      yy=[yy(1:ii-1); xy(2); yy(ii:end)];
    else
      xx=[xx; xy(1)];
      yy=[yy; xy(2)];
      ii=length(xx);
    end
    mousemove(@phsc_move,'upper',xx,yy,ii);
    act=1;
  otherwise
    if iszoom
      switch get(gcbf,'selectiontype')
	case {'alt', 'open'}
	  setappdata(figh,'axlim', getappdata(figh,'axlim0'));
	otherwise
	  xy=get(gca,'currentpoint'); xy = xy(1,1:2);
	  rbbox;
	  xy1=get(gca,'currentpoint'); xy1 = xy1(1,1:2);
	  dd=(xy1(1)-xy(1))^2 + (xy1(2)-xy(2))^2;
	  if dd>5
	    setappdata(figh,'axlim', [sort([xy(1) xy1(1)]) sort([xy(2) xy1(2)])]);
	  else
	    setappdata(figh,'axlim', getappdata(figh,'axlim0'));
	  end
      end
    end
    phsc_redraw(figh,1);
end

if act
  xx = phsc_data{figh}.upper_thr{c}(:,1);
  yy = phsc_data{figh}.upper_thr{c}(:,2);
  nn = find(xx(2:end)<xx(1:end-1));
  xx(nn) = (xx(nn+1)+xx(nn))/2; xx(nn+1)=[];
  yy(nn) = (yy(nn+1)+yy(nn))/2; yy(nn+1)=[];
  phsc_data{figh}.upper_thr{c} = [xx yy];
  
  xx = phsc_data{figh}.lower_thr{c}(:,1);
  yy = phsc_data{figh}.lower_thr{c}(:,2);
  nn = find(xx(2:end)<xx(1:end-1));
  xx(nn) = (xx(nn+1)+xx(nn))/2; xx(nn+1)=[];
  yy(nn) = (yy(nn+1)+yy(nn))/2; yy(nn+1)=[];
  phsc_data{figh}.lower_thr{c} = [xx yy];
  
  phsc_redraw(figh,0);
end

%----------------------------------------------------------------------
function phsc_move(h,xy0,xy1,whch,xx,yy,ii)
global phsc_data
figh=double(get(h,'parent'));
c=phsc_data{figh}.c;

xx(ii)=xy1(1);
yy(ii)=xy1(2);

switch whch
  case 'lower'
    phsc_data{figh}.lower_thr{c} = [xx yy];
  case 'upper'
    phsc_data{figh}.upper_thr{c} = [xx yy];
end

phsc_redraw(figh,0);

%----------------------------------------------------------------------
function phsc_channelselect(h,x)
global phsc_data
figh = double(gcbf);
phsc_data{figh}.c = get(gcbo,'userdata');
set(findobj(gcbf,'tag','channelselect'),'fontw','normal');
set(gcbo,'fontw','bold');
phsc_redraw(figh,1);

function phsc_done(h,x)
figh = double(gcbf);
setappdata(figh,'completed',1);
uiresume(figh);

%----------------------------------------------------------------------
function gdspk = phsc_getdata(figh)
global phsc_data
figh = double(figh);

gdspk.tms=[];
gdspk.amp=[];

if strcmp(phsc_data{figh}.src.type,'spikes')
  for c=1:phsc_data{figh}.C
    idx = find(phsc_data{figh}.src.spk.chs==c);
    tt = phsc_data{figh}.src.spk.tms(idx);
    yy = phsc_data{figh}.src.spk.hei(idx);
    
    x = phsc_data{figh}.lower_thr{c}(:,1);
    y = phsc_data{figh}.lower_thr{c}(:,2);
    [x,ord]=sort(x);
    y = y(ord);
    x=[min([0 min(x)-10]); x(:); max([max(tt) max(x)])+10] ;
    y=[y(1); y(:); y(end)];
    lower_thr = interp1(x,y,tt,'linear');
  
    x = phsc_data{figh}.upper_thr{c}(:,1);
    y = phsc_data{figh}.upper_thr{c}(:,2);
    [x,ord]=sort(x);
    y = y(ord);
    x=[min([0 min(x)-1]); x(:); max([max(tt) max(x)])+10];
    y=[y(1); y(:); y(end)];
    upper_thr = interp1(x,y,tt,'linear');
    
    if mean(upper_thr)<mean(lower_thr)
      ll=lower_thr;
      lower_thr=upper_thr;
      upper_thr=ll;
    end
  
    idx = idx(find(yy>lower_thr & yy<upper_thr));
    
    gdspk.tms = phsc_data{figh}.src.spk.tms(idx);
    gdspk.amp = phsc_data{figh}.src.spk.hei(idx);
  end
end

