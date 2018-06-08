function [yy,tpl]=templatefilter(xx,period_sams,f_max,npers)
% TEMPLATEFILTER - Remove 60 Hz line noise by template filtering
%    yy = TEMPLATEFILTER(xx,period_sams,f_max,npers) removes (nearly) periodic 
%    noise (such as 60 Hz line pickup) from the signal XX. 
%    PERIOD_SAMS is the period of the noise, which need not be integer.
%    E.g., for 60 Hz noise removal from a signal sampled at 10 kHz, you'd
%    set PERIOD_SAMS = 10000/60.
%    F_MAX is the maximum frequency expect to exist in the periodic noise;
%    noise (or signal) above that frequency is not treated. Measured
%    in units of the sample frequency. Typical: F_MAX = 500/10000.
%    NPERS is the number of periods to use for estimation.
%    TEMPLATEFILTER works on vectors, or on the columns of NxD arrays.
%    PERIOD_SAMS may also be a reference signal which should have the same
%    length as xx. In that case, the period is determined from the upward
%    crossings of the reference.
%    [yy, tpl] = TEMPLATEFILTER(...) also returns the template. This only
%    works if XX is a vector.
%    Ordinarilty, a butterworth low-pass filter is used to create the 
%    estimate to be subtracted. Set NPERS to a negative number to use
%    a median filter of width 2*|NPERS| + 1 instead.

if nargin<4
  npers = 50;
end
if nargin<3
  f_max=[];
end

if prod(size(xx)) ~= length(xx)
  % Not a vector
  S=size(xx);
  xx = reshape(xx,[S(1) prod(S(2:end))]);
  [X,Y] = size(xx);
  yy = zeros(X,Y);
  for y=1:Y
    yy(:,y) = templatefilter(xx(:,y),period_sams,f_max,npers);
  end
  yy = reshape(yy,S);
  return
end

% Step zero: convert a reference signal into a period.
if length(period_sams)>1
  m = mean(period_sams);
  s = std(period_sams);
  
  [ion,iof] = schmitt(period_sams,m+s/2,m-s/2);
  period_sams = mean(diff(ion));
end

% Step one: resample the original signal to make period_sams be integer.
X=length(xx);
int_sams = floor(period_sams);
rat = period_sams / int_sams;
zz = interp1([1:X],xx,[1:rat:X],'linear');

% Step two: reshape into a matrix with one period per column (dropping
% the final partial period).
Z = length(zz);
N = floor(Z/int_sams);
zz = reshape(zz(1:N*int_sams),[int_sams N]);

% Step three: filter consecutive periods
if npers>0
  [b,a]=butterlow1(1/npers);
  zz = filtfilt(b,a,zz')';
else
  zz = medianfltn(zz', npers)';
end

% Step four: Smooth the template by assuming there are no
% high frequency components to the pickup.
if ~isempty(f_max)
  [b,a]=butterlow1(f_max); % Where f_max is in units of sample frequency.
  zz = filtfilt(b,a,zz);
end

% Step five: add an extra period at the end, based on the final period,
% to compensate for data cut in step two.
zz(:,N+1)=zz(:,N);

% Step six: Remove DC from the template.
zz = zz - repmat(mean(zz),[int_sams 1]);

% Step seven: reshape back to a vector, and resample back to original frequency.
zz = zz(:);
Z=length(zz);
zz = interp1([1:Z],zz,[1:1/rat:Z],'linear');

% Step eight: subtract the template from the original signal.
yy = xx - reshape(zz(1:X),size(xx));

if nargout>=2
  tpl=reshape(zz(1:X),size(xx));
end
