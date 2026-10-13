clear all
close all

pkg load signal
format long

fs=5e6;                                     % sampling rate
fcode=2.5e6;                                % SATRE code rate
N=6e5*2
Ncode=1e4;
display_fig=0;
Nint=1;

function [station,poscnt,position]=search_peaks(Nelems,sol,station,position,poscnt,figpos,fileindex,Nint,m,N)
  for n=Nelems:Nelems:length(sol)-Nelems-1 % stop early to avoid windowing effect on last element
    station(m)=m;
    [~,postmp]=max(sol(n:n+Nelems-1));
    if (postmp>1) && (postmp<Nelems)
       postmp=n+postmp-1;
       correction=(sol(postmp-1)-sol(postmp+1))/(sol(postmp+1)+sol(postmp-1)-2*sol(postmp));
       position(poscnt(m),figpos)=postmp+correction+fileindex*(N*(2*Nint+1)-2*Nelems);
       poscnt(m)=poscnt(m)+1;
     end
  end
end

dold=[];
position=[];
Nelems=Ncode*fs/fcode*(2*Nint+1)
P=10                                         % number of stations searched
dd=dir('/tmp/sat*bin');                        % record location
load ./taps.txt
for m=1:size(taps)(1)
    codef(:,m)=conj(fftshift(fft(repelem(taps(m,:)*2-1,fs/fcode*(2*Nint+1)),N*(2*Nint+1))));  % resample code at data rate and interpolate by 0-padding
end
frequency=zeros(size(taps)(1)+1,1);          % +1 for unknown station
station=zeros(size(taps)(1)+1,1);            % +1 for unknown station
for l=1:length(dd)                           % loop through records
  f=fopen(['/tmp/',dd(l).name]);
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
	 if kk<length(k)
           df=fr(k(kk))/2;                        % frequency offset is half the squared signal freq.
           if ((abs(df)<1e6)&&(res(k(kk))>0)&&(abs(df)>10))     % remove peaks already measured or too far from center
             res(k(kk)-20:k(kk)+20)=0;            % remove peaks broader than 1 sample
             t=[0:length(d)-1]'/fs;
             st=d.*exp(-j*2*pi*df*t);
             sf=[zeros(Nint*N,1) ; fftshift(fft(st)).*hamming(length(d)) ; zeros(Nint*N,1)]; % interpolate
             mm=find((frequency>=df-50)&(frequency<=df+50));
             done=0;
             if (isempty(mm))
		     printf("empty(mm)")
               m=1;
               do
                 sol=abs(ifft((sf.*codef(:,m)))); % codef is already conj(fft)
                 if max(sol)>median(sol)*10         % TODO ADAPT
                   if frequency(m)==0
                      frequency(m)=df;
                   end
                   [station,poscnt,position]=search_peaks(Nelems,sol,station,position,poscnt,figpos,fileindex,Nint,m,N);
                   done=1;
                   if (poscnt(m)>2)
                     printf("df=%.1f\tm=%d\t%f\n",df,m,position(poscnt(m)-1,figpos)-position(poscnt(m)-2,figpos)/fs/(2*Nint+1));
                   end
                   if (display_fig==1)
                     subplot(P/2,2,figpos);
                     plot([0:length(sol)-1]/fs,sol);hold on
                     legend([num2str(m),' ',num2str(df)])
                   end
                 end
                 m=m+1;
               until ((m==size(taps)(1)+1)||(done==1))
             else
               m=mm(1)
               printf("df=%f\n", df);
	       if (station(m)!=999)   % unknown !
                 sol=abs(ifft((sf.*codef(:,m)))); % codef is already conj(fft)
                 [station,poscnt,position]=search_peaks(Nelems,sol,station,position,poscnt,figpos,fileindex,Nint,m,N);
	       end
             end
	     if (m==size(taps)(1)+1)
		     frequency(m)=df;
		     station(m)=999;
	     end
             figpos=figpos+1;
           end
	 end
      until (figpos==P+1);
      fileindex=fileindex+1;
      dold=d(end-2*Nelems+1:end);
    end
  until (length(d)<N)
end
save -mat all.mat position station res
