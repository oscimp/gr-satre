pkg load signal

fs=5e6;                                     % sampling rate
fcode=2.5e6;                                % SATRE code rate
P=8                                         % number of stations searched
d=dir('/tmp/s*bin');                        % record location
load ../taps.txt
for l=2:2                                   % loop through records
  f=fopen(['/tmp/',d(l).name]);
  d=fread(f,2e5,'float');                   % assume 32 bit complex float
  d=d(1:2:end)+j*d(2:2:end);
  fr=linspace(-fs/2,fs/2-fs/length(d),length(d));
  res=abs(fftshift(fft(d.^2)));             % search for BPSK modulated signals
  median(res)
  k=find(res>median(res)*5);  % ADAPT
  kk=0;                                     % loop through squared signal FFT() peaks
  figpos=1;
  do
     kk=kk+1;
     df=fr(k(kk))/2                         % frequency offset is half the squared signal freq.
     if ((abs(df<1e6))&& (res(k(kk))>0))    % remove peaks already measured or too far from center
       res(k(kk)-20:k(kk)+20)=0;            % remove peaks broader than 1 sample
       t=[0:length(d)-1]'/fs;
       s=d.*exp(-j*2*pi*df*t);              % LO
       for m=1:size(taps)(1)
         code=repelem(taps(m,:),fs/fcode);  % resample code at data rate
         sol=(abs(xcorr(s,code)));
	 if max(sol)>median(sol)*20  % ADAPT
            subplot(P/2,2,figpos);
            plot([0:length(sol(round(length(sol)/2):end))-1]/fs,sol(round(length(sol)/2):end));hold on
	    legend([num2str(m),' ',num2str(df)])
	    figpos=figpos+1;
	    m
	 end
       end
     end
  until (figpos==P+1);
end
