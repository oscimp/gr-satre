clear all
close all
pkg load signal
format long

global temps freq fcode code fs Nint    % save time by avoiding unnecessary fixed parameter arguments
fs=5e6;         % S/s
freqcode=2.5e6;    % chips/s
dt=0.400        % us = 1/2.5 Mchips/s
invfs=1/fs*1E9; % inverse of fs in ns
filename='230321_13h10m00__ch1TXMon17p8dBm_ch2RXMon_11dBgainB210.bin';
freqoffset=[ -8944 4472 -13416 -44721 -26833 17889 -17889 0   31305  8944 26833 -4472 13416 -22631 22631]
stationindex=1+[0   9    14     7      6     4      3     1      15   2     5    10     11    12    13]
station=9; % LTFB

% graphics_toolkit('gnuplot')
Nint=1;
remote=0
OP=0
affiche=0;
debug=1
datalocation='./'

function [xval,indice,correction,SNRr,SNRi,puissance,puissancecode,puissancenoise]=processing(d,k,df)
      global temps freq fcode code fs Nint
      % if (abs(df1(p))<(freq(2)-freq(1))) df1(p)=0;end;
      lo=exp(-j*2*pi*df*temps);         % coarse frequency offset
      y=d.*lo;                          % coarse frequency transposition
      ffty=fft(y);
%      prnmap=ifft(fcode.*conj(ffty));     % xcorr
%      [~,indice]=max(abs(prnmap));
%      xval=prnmap(indice);

      prnmap=fftshift(fcode.*conj(ffty));     % xcorr
      prnmap=[zeros(length(y)*(Nint),1) ; prnmap ; zeros(length(y)*(Nint),1)]; % interpolation to 3x samp_rate
      prnmap=(ifft(fftshift(prnmap)));  % back to time /!\ NO outer fftshift for 0-delay at left
      yint=zeros(length(y)*(2*Nint+1),1);
      yint(1:length(y)/2)=ffty(1:length(y)/2);
      yint(end-length(y)/2+1:end)=ffty(length(y)/2+1:end);
      yint=ifft(yint);
      codetmp=repelems(code,[[1:length(code)] ; ones(1,length(code))*(2*Nint+1)])'; % interpolate
      cm=1;
      for codeindex=1:length(code)*(2*Nint+1):length(prnmap)-length(code)*(2*Nint+1)+1
        [~,indice(cm)]=max(abs(prnmap(codeindex:codeindex+length(code)*(2*Nint+1)-1)));
        xval=prnmap(indice(cm)+codeindex-1);
        if ((indice(cm)+codeindex-1-1)>=1)
           xvalm1=prnmap(indice(cm)+codeindex-1-1);
        else
           xvalm1=prnmap(end);
        end
        if ((indice(cm)+codeindex-1+1)<length(prnmap))
           xvalp1=prnmap(indice(cm)+codeindex-1+1);
        else
           xvalp1=prnmap(1);
        end
        correction(cm)=(abs(xvalm1)-abs(xvalp1))/(abs(xvalm1)+abs(xvalp1)-2*abs(xval))/2;
% SNR computation
%      yf=fftshift(fft(y));
%      yint=[zeros(length(y)*(Nint),1) ; yf ; zeros(length(y)*(Nint),1)]; % interpolation to 3x samp_rate
%      yint=(ifft(fftshift(yint)));       % back to time /!\ outer fftshift for 0-delay at center
        yintmp=yint(codeindex:codeindex+length(code)*(2*Nint+1)-1);
%plot(angle(yintmp(1:2000))); 
%hold on
%plot(([codetmp(indice(cm)-1:end) ; codetmp(1:indice(cm)-2)])(1:2000));
        if (indice(cm)>2)
           yincode=[codetmp(indice(cm)-1:end) ; codetmp(1:indice(cm)-2)].*yintmp;
        else
           yincode=codetmp.*yintmp;
        end
        SNRr(cm)=mean(real(yincode))^2/var(yincode);
        SNRi(cm)=mean(imag(yincode))^2/var(yincode);
        puissance(cm)=var(y);
        puissancecode(cm)=mean(real(yincode))^2+mean(imag(yincode))^2;
        puissancenoise(cm)=var(yincode);
	cm=cm+1;
      end
end

dirlist=dir([datalocation,filename]);
taps=load('../../taps.txt');taps=taps';
for k=1:32
  sol=taps(:,k);
  prn=[];
  t=0;
  for m=1:length(sol)  % length of PRN
    do
      t=t+1/fs*1e6;
      prn=[prn sol(m)];
    until (t>dt);
    t=t-dt;
  end 
  tapsi(:,k)=prn(1:end-1)-mean(prn(1:end-1));
end
code=tapsi(:,stationindex(station));
fcode=fft(code);

for dirnum=1:length(dirlist)
  dirlist(dirnum).name
  eval(["f=fopen('",datalocation,"/",dirlist(dirnum).name,"');"]);
  d=fread(f,fs*4*4,'int16');         % 10s
  p=1;
  pfreq=1;
  temps=[0:length(code)-1]'/fs;
  freq=linspace(-fs/2,fs/2,fs);
  printf("n\tdt1\tdf1\tP1\tSNR1\tdt2\tdf2\tP2\tSNR2\r\n");
  k=find((freq<2*freqoffset(station)+6000)&(freq>2*freqoffset(station)-6000));
  dold=[];
  do
    d=fread(f,fs*4,'int16');         % 1s
    longueur=length(d);
    if (longueur==fs*4)  
      d=d(1:2:end)+j*d(2:2:end);
      if (remote==1)
         d2=fftshift(abs(fft(d(1:2:end).^2))); % 0.5 Hz accuracy
         d=[dold ; d(1:2:end)+j*d(2:2:end)];
      else
         d2=fftshift(abs(fft(d(2:2:end).^2))); % 0.5 Hz accuracy
         d=[dold ; d(2:2:end)+j*d(2:2:end)];
      end
      [~,df(pfreq)]=max(d2(k));df(pfreq)=df(pfreq)+k(1)-1;df(pfreq)=freq(df(pfreq))/2;df(pfreq)
      dindex=1;
      do
        dpart=d(dindex:dindex+length(fcode)-1);dpart=dpart-mean(dpart);
        [xval1(p),indice1(p),correction1(p),SNR1r(p),SNR1i(p),puissance1(p),puissancecode,puissancenoise]=processing(dpart,k,df(pfreq));
        indice1(p)=floor(indice1(p)/(2*Nint+1));
        if (10*log10(SNR1i(p)+SNR1r(p))>-30)
           if (((indice1(p)>3)&&(indice1(p)<length(code)/2)) || ((indice1(p)<length(code)-2)&&(indice1(p)>length(code)/2)))
printf("MOVED %d\n",indice1(p));
              if ((dindex-indice1(p)+1)<0) 
                 dindex=dindex+length(fcode);
              end 
              dindex=dindex-(indice1(p))+1;
              dpart=d(dindex:dindex+length(fcode)-1); dpart=dpart-mean(dpart); % measurement
              [xval1(p),indice1(p),correction1(p),SNR1r(p),SNR1i(p),puissance1(p),puissancecode,puissancenoise]=processing(dpart,k,df(pfreq));
           end
% figure; plot(temps,conv(angle(y.*code'),ones(100,1)/100)(50:end-50),'.');
% xlabel('time (s)');  ylabel('arg(code.*data) (s)')
        end

%        printf("%d\t%.12f\t%.3f\t%.1f\t%.1f\r\n",p,(indice1(p)-1+correction1(p))/fs/(2*Nint+1),df(pfreq),10*log10(puissance1(p)),10*log10(SNR1i(p)+SNR1r(p)))
        p=p+1;
        dindex=dindex+length(fcode);
      until (dindex>=length(d)-length(fcode))
    end
    dold=d(dindex:end);
    pfreq=pfreq+1;
  until (longueur<length(fcode)*4);
  fclose(f)

  nom=strrep(dirlist(dirnum).name,'.bin','.mat');
  if (remote!=1)
    eval(['save -mat local',nom,' corr* df indic* SNR* code puissan* xval*']);
  else
    eval(['save -mat remote',nom,' corr* df indic* SNR* code puissa* xval*']);
  end
  clear corr* df* indic* p SNR* puissa* xval*
end
