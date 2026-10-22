clear all
close all

pkg load signal
format long

fs=5e6;                                     % sampling rate
fcode=2.5e6;                                % SATRE code rate
Ncode=1e4;                                  % SATRE code length
N=4e5*2                                     % chunk size (arbitrary)
display_fig=0;
Nint=1;                                     % interpolation by 2xN+1
P=20                                        % number of stations searched

function [station,poscnt,position]=search_peaks(Nelems,sol,station,position,poscnt,fileindex,Nint,m,N)
  for n=Nelems:Nelems:length(sol)-Nelems-1  % stop early to avoid windowing effect on last element
    station(m)=m;
    [~,postmp]=max(sol(n:n+Nelems-1));
    if (postmp>1) && (postmp<Nelems)
       postmp=n+postmp-1;
       correction=(sol(postmp-1)-sol(postmp+1))/(sol(postmp+1)+sol(postmp-1)-2*sol(postmp));
       position(poscnt(m),m)=postmp+correction+fileindex*(N*(2*Nint+1)-2*Nelems);
       poscnt(m)=poscnt(m)+1;
     end
  end
end

dold=[];
position=[];
df=zeros(32,1);
Nelems=Ncode*fs/fcode*(2*Nint+1)
dfstation=zeros(P,1);
dd=dir('/tmp/sat*bin');                     % record location
load ./taps.txt
for m=1:size(taps)(1)
    codef(:,m)=conj(fftshift(fft(repelem(taps(m,:)*2-1,fs/fcode*(2*Nint+1)),N*(2*Nint+1))));  % resample code at data rate and interpolate by 0-padding
end
station=zeros(size(taps)(1),1);
for l=1:length(dd)                          % loop through records
  f=fopen(['/tmp/',dd(l).name]);
  poscnt=ones(size(taps)(1),1);
  fileindex=0;
  do
    if (length(dold)<Nelems/(2*Nint+1))
       d=fread(f,2*N,'float');              % assume 32 bit complex float
    else
       d=fread(f,2*N-2*2*Nelems/(2*Nint+1),'float');   % assume 32 bit complex float
    end
    d=[dold ; d(1:2:end)+j*d(2:2:end)];
    if (length(d)==N)
      if (display_fig==1)
        figure
      end
      if (df(1)==0)
        fr=linspace(-fs/2,fs/2-fs/length(d),length(d));
        res=abs(fftshift(fft(d.^2)));       % search for BPSK modulated signals
        k=find(abs(fr)<10);
        res(k)=0;                           % DC offset
        k=find(abs(fr)<400e3);
        res=res(k);
        ressave=res;
        fr=fr(k);
      end
      figpos=1;
      echecs=0;
      do
        if df(figpos)==0
          [~,tmp]=max(res);                 % next fft(signal^2) peak
          res(tmp-20:tmp+20)=0;             % clear peak under investigation
          df(figpos)=fr(tmp)/2;             % record frequency offset
          t=[0:length(d)-1]'/fs;
          st=d.*exp(-j*2*pi*df(figpos)*t);
          sf=[zeros(Nint*N,1) ; fftshift(fft(st)).*hamming(length(d)) ; zeros(Nint*N,1)]; % interpolate
          m=1;
          done=0;
          do
            sol=abs(ifft((sf.*codef(:,m))));% codef is already conj(fft)
            if max(sol)>median(sol)*10      % TODO ADAPT
              [station,poscnt,position]=search_peaks(Nelems,sol,station,position,poscnt,fileindex,Nint,m,N);
              dfstation(figpos)=m;
              done=1;                       % no need to look further for this spectral component
              if (poscnt(m)>2)
                printf("df=%.1f\tm=%d\t%f\n",df(figpos),m,position(poscnt(m)-1,m)-position(poscnt(m)-2,m)/fs/(2*Nint+1));
              end
              if (display_fig==1)
                subplot(P/2,2,figpos);
                plot([0:length(sol)-1]/fs,sol);hold on
                legend([num2str(m),' ',num2str(df)])
              end
            end
            m=m+1;
          until ((m==size(taps)(1)+1)||(done==1))
          if (done==0)
            printf("echec %f\n",df(figpos));
            dfstation(figpos)=999;
            df(figpos)=999;
            echecs=echecs+1;
          end
        else
          m=dfstation(figpos);
          printf("df=%f %d\n", df(figpos),m);
          if (m!=999)   % unknown !
            t=[0:length(d)-1]'/fs;
            st=d.*exp(-j*2*pi*df(figpos)*t);
            sf=[zeros(Nint*N,1) ; fftshift(fft(st)).*hamming(length(d)) ; zeros(Nint*N,1)]; % interpolate
            sol=abs(ifft(fftshift(sf.*codef(:,m)))); % codef is already conj(fft)
	    if (poscnt(m)<1240)
               [station,poscnt,position]=search_peaks(Nelems,sol,station,position,poscnt,fileindex,Nint,m,N);
	    end
          end
	end
        figpos=figpos+1;
      until ((figpos==P+1) || (echecs>2));  % 3 failures means all stations have been detected
      if (echecs>2)
        dfstation(figpos:end)=999;          % don't analyze subsequent peaks
	df(figpos:end)=999;
      end
      fileindex=fileindex+1;                % position within the file
      dold=d(end-2*Nelems/(2*Nint+1)+1:end);% keep last items (@ fs)
    end
       length(d)
    length(position)
  until (length(d)<N)
end
save -mat all.mat position station dfstation df
% remove ressave to save space
