pkg load signal

fs=5e6;
fcode=2.5e6;
P=8
d=dir('/tmp/s*bin');
load ../taps.txt
for l=2:2
  f=fopen(['/tmp/',d(l).name]);
  d=fread(f,2e5,'float');
  d=d(1:2:end)+j*d(2:2:end);
  fr=linspace(-fs/2,fs/2-fs/length(d),length(d));
  res=abs(fftshift(fft(d.^2)));
  median(res)
  k=find(res>median(res)*5);  % ADAPT
  kk=0;
  figpos=1;
  do
     kk=kk+1;
     df=fr(k(kk))/2
     if ((abs(df<1e6))&& (res(k(kk))>0))
       res(k(kk)-20:k(kk)+20)=0;
       t=[0:length(d)-1]'/fs;
       s=d.*exp(-j*2*pi*df*t);
       for m=1:size(taps)(1)
         code=repelem(taps(m,:),fs/fcode);
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
