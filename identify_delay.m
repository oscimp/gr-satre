clear all  % comment during tests to avoid recalculation of frequency offset
close all
pkg load signal

fs=5e6;      % S/s
fcode=2.5e6; % chips/s
dt=0.400     % us = 1/2.5 Mchips/s
N=65536*2;
invfs=1/fs*1E9;
filename='220409_08h06_satre2chan_short_5MSps_B210_20dB_50dB_extclk.bin';
% filename='220409_10h06_satre2chan_short_5MSps_X310_1xMSA_extclk.bin'
freqoffset=[ -8944 6300 -13000 -40000 -24000 18000 -17000 1080 31300]
stationindex=1+[0   9    14     7      6     4      3     1      15  ]
%               OP                           PTB    SP    NPL   LTFB
%  -4.2887e+04  -3.9187e+04  -2.6884e+04  -2.4996e+04  -1.6070e+04  -1.1587e+04  -7.1049e+03
%        7           16            ?           6            1           14            0
%   1.8215e+03   6.3038e+03   1.9713e+04   3.3140e+04
%        1          (9)           4           15
%                                         LTFB (31.3k)

if (exist('xrecu')==0)
  fichier=fopen(filename);
  if (exist("read_short_binary")==0)
     printf("Please download read_short_binary.m at https://github.com/gnuradio/gnuradio/blob/master/gr-utils/octave/read_short_binary.m")
  else
     x=read_short_binary(filename,1E6);
  end
  if (isempty(strfind(filename,"B210"))==0)
    xrecu=x(3:4:end)+j*x(4:4:end); 
  else
    xrecu=x(1:4:end)+j*x(2:4:end); 
  end
  xrecu=xrecu/32767;
  xrecu=xrecu(end-N:end);
  temps=[0:length(xrecu)-1]'/fs;
  freq=linspace(-fs/2,fs/2,N);
  k=find((freq>-90000)&(freq<90000));  % possible frequency offsets (x2)
  s=fftshift(abs(fft(xrecu.^2,N)));    % cancel BPSK modulation and search offset
  solution=find(s(k)>max(s(k)/4));solution=k(solution);
  taps=load('taps.txt');taps=taps';
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
  mysolution=[];    % search local maximum in each contiguous interval
  posd=solution(1)
%  if (length(solution)==1) mysolution=posd;end
  for k=2:length(solution)
    if ((solution(k)-solution(k-1))>3)
      [~,tmp]=max(s(posd:solution(k-1)));
      mysolution=[mysolution tmp+posd-1];
      posd=solution(k);
%    else
%      mysolution=[mysolution posd];
%      posd=solution(k);
    end
  end
  freq(mysolution)/2
  fclose(fichier);
end

for station=1:length(freqoffset)
  station
  %plot(freq,s);
  %hold on
  %plot(freq(mysolution),max(s),'x')
  fichier=fopen(filename);
  dftmp=find((freq(mysolution)/2>freqoffset(station)-2500)&(freq(mysolution)/2<freqoffset(station)+2500));
  if (isempty(dftmp)==0)
    ref=[tapsi(:,stationindex(station)) ; zeros(length(tapsi(:,1))*99,1)]; % ref=ref-mean(ref); % 1=OP mean already removed
    mytapsi=conj(fft(ref));
    longueur=length(mytapsi)*4;
    temps=[0:longueur/4-1]'/fs;
    df=mean(freq(mysolution(dftmp)))/2
    lo=exp(-j*2*pi*df*temps);
  
    compteur=0;
    corrections=[];
    xvals=[];
    xvalm1s=[];
    xvalp1s=[];
    indices=[];
    do
      x=fread(fichier,longueur,'int16'); 
      if (length(x)==longueur)
        if (isempty(strfind(filename,"B210"))==0)
          xrecu=x(3:4:end)+j*x(4:4:end);
        else
          xrecu=x(1:4:end)+j*x(2:4:end); 
        end
        xrecu=xrecu/32767;
%do refait=0;
        y=xrecu.*lo;                    % frequency transposition
        prnmap01=ifft(fft(y).*mytapsi); % correlation
        %plot(abs(prnmap01))
        %xlim([0 length(prnmap01)])
%       posmax=find(prnmap01>max(prnmap01)/1.5); % too coarse
      % new search method 
        ncode=fs/fcode*length(taps);
        p=1;
        pos=1;
        ajustement=0;
        correction=[];
        xval=[];
        xvalm1=[];
        xvalp1=[];
        indice=[];
        do
          if ((pos+ncode)>length(prnmap01))  % last part of data
             [~,indice(p)]=max(abs(prnmap01(pos:end)));
          else
             [~,indice(p)]=max(abs(prnmap01(pos:pos+ncode)));
          end
          indice(p)=indice(p)+pos-1;
          xval=[xval prnmap01(indice(p))];
          xvalm1=[xvalm1 prnmap01(indice(p)-1)];
          xvalp1=[xvalp1 prnmap01(indice(p)+1)];
          [u,v]=polyfit([-1:+1]',abs(prnmap01([indice(p)-1:indice(p)+1])),2);
          correction(p)=-u(2)/2/u(1);
          pos=pos+ncode;
          p=p+1;
        until (pos>length(prnmap01));
        [a,b]=polyfit([0:length(indice)-1]'*4e-3,unwrap(angle(prnmap01(indice))*2)/2,1);
        frequency_residue=a(1)/2/pi;  % verification: a/2/pi*fs must be close to 0
        if (abs(frequency_residue)>1) 
           lo=lo.*exp(-j*2*pi*frequency_residue*temps); printf("frequency changed\n");
        end
%until (refait==0);
        indices=[indices indice+compteur*longueur/4];
        corrections=[corrections correction];
        xvals=[xvals xval];
        xvalm1s=[xvalm1s xvalm1];
        xvalp1s=[xvalp1s xvalp1];
        compteur=compteur+1;
      end
    until (length(x)<longueur)  % will go to 500
    % until (compteur>75)  % will go to 500
  
    eval(['corrections',num2str(stationindex(station)),'=corrections;']);
    eval(['indices',num2str(stationindex(station)),'=indices;']);
    eval(['xvals',num2str(stationindex(station)),'=xvals;']);
    eval(['xvalm1s',num2str(stationindex(station)),'=xvalp1s;']);
    eval(['xvalp1s',num2str(stationindex(station)),'=xvalm1s;']);
    fclose(fichier);
    
    if (stationindex(station)>1)
      if (isempty(indices)==0)
        figure;
        subplot(221)
        final=invfs*(diff(indices+corrections));
        plot([0:length(final)-1]*4e-3,final)
        xlabel('time (s)');ylabel('delay (ns)');legend([num2str(stationindex(station))])
        subplot(223)
        final=invfs*(diff(indices+corrections)-diff(indices1+corrections1));
        k=find(abs(final)<90);final10=final(k);
        plot([0:length(final)-1]*4e-3,final)
        xlabel('time (s)');ylabel('delay (ns)');legend([num2str(stationindex(station)),'-OP1'])
        mean(final)
        std(final)
        subplot(222)
        u=angle(xvals.*exp(-j*unwrap(angle(xvals)*2)/2));
        k=find(u<-2);u(k)=u(k)+2*pi;
        plot([0:length(u)-1]*4e-3,u,'x');
        xlabel('time (s)');ylabel('phase (rad)');
        subplot(224)
        bits=floor(length(u)/250);
        sentences=(reshape(u(1:250*bits),250,bits)); % 250 bits/second, 1 message/second
        imagesc(sentences')
        xlabel('fast time (sample)')
        ylabel('slow time (sentence)')
      end
    else
        final=invfs*(diff(indices+corrections));
        plot([0:length(final)-1]*4e-3,final)
        xlabel('time (s)');ylabel('delay (ns)');legend('OP1')
    end
  else
    printf("Failed to detect code %d",stationindex(station))
  end  
end
