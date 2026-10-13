pkg load signal
format long

fs=5e6;                                     % sampling rate
fcode=2.5e6;                                % SATRE code rate
N=6e5*2
Ncode=1e4;
display_fig=0;
Nint=1;

dold=[];
Nelems=Ncode*fs/fcode*(2*Nint+1)
P=8                                         % number of stations searched
d=dir('/tmp/s*bin');                        % record location
load ./taps.txt
for m=1:size(taps)(1)
    codef(:,m)=conj(fftshift(fft(repelem(taps(m,:)*2-1,fs/fcode*(2*Nint+1)),N*(2*Nint+1))));  % resample code at data rate and interpolate by 0-padding
end
for l=1:length(d)                           % loop through records
  f=fopen(['/tmp/',d(l).name]);
  poscnt=ones(size(taps)(1),1);
  fileindex=0;
  do
    if (length(dold)<Nelems)
	   d=fread(f,2*N,'float');                   % assume 32 bit complex float
    else
           d=fread(f,2*N-2*2*Nelems,'float');                   % assume 32 bit complex float
    end
    d=[dold ; d(1:2:end)+j*d(2:2:end)];
    if (length(d)==N)
      if (display_fig==1)
        figure
      end
      fr=linspace(-fs/2,fs/2-fs/length(d),length(d));
      res=abs(fftshift(fft(d.^2)));             % search for BPSK modulated signals
      % median(res)
      if (exist('k')==0)
        k=find(res>median(res)*5);              % TODO ADAPT
      end
      kk=0;                                     % loop through squared signal FFT() peaks
      figpos=1;
      do
         kk=kk+1;
         df=fr(k(kk))/2;                        % frequency offset is half the squared signal freq.
         if ((abs(df)<1e6)&&(res(k(kk))>0))     % remove peaks already measured or too far from center
           res(k(kk)-20:k(kk)+20)=0;            % remove peaks broader than 1 sample
           t=[0:length(d)-1]'/fs;
	   st=d.*exp(-j*2*pi*df*t);
	   sf=[zeros(Nint*N,1) ; fftshift(fft(st)).*hamming(length(d)) ; zeros(Nint*N,1)]; % interpolate
           for m=1:size(taps)(1)
             sol=abs(ifft((sf.*codef(:,m)))); % codef is already conj(fft)
             if max(sol)>median(sol)*10         % TODO ADAPT
               for n=Nelems:Nelems:length(sol)-Nelems-1 % stop early to avoid windowing effect on last element
                  station(figpos)=m;
		  [~,postmp]=max(sol(n:n+Nelems-1));
		  if (postmp>1) && (postmp<Nelems)
		     postmp=n+postmp-1;
		     correction=(sol(postmp-1)-sol(postmp+1))/(sol(postmp+1)+sol(postmp-1)-2*sol(postmp));
		     position(poscnt(m),figpos)=postmp+correction+fileindex*(N*(2*Nint+1)-2*Nelems);
		     positioni(poscnt(m),figpos)=postmp+fileindex*N*(2*Nint+1);
		     poscnt(m)=poscnt(m)+1;
		  end
               end
	       if (poscnt(m)>2)
	          printf("df=%.1f\tm=%d\t%f\n",df,m,position(poscnt(m)-1,figpos)-position(poscnt(m)-2,figpos)/fs/(2*Nint+1));
	       end
	       if (display_fig==1)
                 subplot(P/2,2,figpos);
                 plot([0:length(sol)-1]/fs,sol);hold on
                 legend([num2str(m),' ',num2str(df)])
	       end
               figpos=figpos+1;
             end
           end
         end
    until (figpos==P+1);
    fileindex=fileindex+1;
    dold=d(end-2*Nelems+1:end);
    length(dold)
  end
  until (length(d)<N)
end
