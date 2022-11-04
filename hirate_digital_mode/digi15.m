% 3 = SP01, SN 262 = 100000110         %( 4 = PTB,  SN 076 = 001001100 )

clear all
close all
pkg load signal

% https://www.matrixlab-examples.com/gray-code.html
%function b = gray2bin(g)
%b(1) = g(1);
%for i = 2 : length(g);
%    x = xor(str2num(b(i-1)), str2num(g(i)));
%    b(i) = num2str(x);
%end

% load digital15.mat   % code index +1 since index starting at 0 and matlab at 1
dirlist=dir('2210*mat');
for dirnum=1:length(dirlist)
  %for station=[3 4 7 8]  % 5 15 10
  eval(['load ',dirlist(dirnum).name])
  for station=[4]% 3]
    eval(['u=angle(xvals',num2str(station),'.*exp(-j*unwrap(angle(xvals',num2str(station),')*2)/2));']); % remove phase fluctuation
    k=find(u<-2);u(k)=u(k)+2*pi;                          % 2pi phase addition
    k=find(u<=1);u(k)=0;                                  % threshold
    k=find(u>1);u(k)=1;

    output=zeros(1,length(u)-1);          % remove differential encoding
    for k=1:length(u)-1
      if (u(k)==u(k+1)) output(k)=1; else output(k)=0; end
    end

    debut1=findstr(ones(16,1),output);   % find 16 adjacent bits to 1
    debut0=findstr(zeros(16,1),output);  % find 16 contiguous 0
    if (isempty(debut1)) debut=debut0(1);
      else if (isempty(debut0)) debut=debut1(1);
        else if (debut0(1)<debut1(1)) debut=debut0(1);
          else debut=debut1(1);
        end
      end
    end
    if ((dirnum==3)&&(station==4)) debut=debut+250-31+35*250;end  % (manual selection)
    if ((dirnum==4)&&(station==4)) debut=debut+250-18;end  % (manual selection)
    if ((dirnum==1)&&(station==4)) output=1-output;debut=debut+250*24+16+122+(000)*250;end
    if ((dirnum==2)&&(station==4)) output=1-output;debut=debut+1;end
    output=output(debut:end);
    bits=floor(length(output)/250);                            % number of sentences
%    diff(findstr(output,[1 0 0  0 0 0 1 1 0]))(1:10)
%    diff(findstr(output,fliplr([1 0 0  0 0 0 1 1 0])))(1:10)
%    diff(findstr(output,1-[1 0 0  0 0 0 1 1 0]))(1:10)
%    diff(findstr(output,fliplr(1-[1 0 0  0 0 0 1 1 0])))(1:10)
    sentences=(reshape(output(1:250*bits),250,bits)); % 250 bits/second, 1 message/second
    eval(['bits',num2str(dirnum),'_',num2str(station),'=sentences'';']);
    figure
    imagesc(sentences');title([strrep(dirlist(dirnum).name,'_',' '),' SATRE',num2str(station)])
  % ylabel([strrep(dirlist(dirnum).name,'_',' '),' station ',num2str(station)]);
  %motif=([1 0 1 1 0 1 0 1 1 1 ]); % LTFB SATRE ID=727
  %x=(xcorr(output-mean(output),motif-mean(motif)));
  %k=find(abs(x)>2.1);
  %diff(k)
  %figure
  %plot(x(floor(length(x)/2:end)))
  end
end

n=55

figure
imagesc(bits3_4(1:680,:)-bits4_4(1:680,:))

figure
% k1=find((bits1_4(:,n+5)==1)&(bits1_4(:,n+0)==1)&(bits1_4(:,n+1)==0)&(bits1_4(:,n+2)==0)&(bits1_4(:,n+3)==1)&(bits1_4(:,n+4)==0));
k1=find((bits1_4(:,n+0)==1)&(bits1_4(:,n+1)==0)&(bits1_4(:,n+2)==0)&(bits1_4(:,n+3)==1)&(bits1_4(:,n+4)==0));
k1=k1(1:150);
imagesc(bits1_4(k1,:));

for indice=1:length(k1)
  chaine="";
  for m=71:79
    chaine=[chaine num2str(1-bits1_4(k1(indice),m))];
  end
  bin2dec(gray2bin(chaine))
end

figure
% k2=find((bits2_4(:,n+5)==1)&(bits2_4(:,n+0)==1)&(bits2_4(:,n+1)==0)&(bits2_4(:,n+2)==0)&(bits2_4(:,n+3)==1)&(bits2_4(:,n+4)==0));
k2=find((bits2_4(:,n+0)==1)&(bits2_4(:,n+1)==0)&(bits2_4(:,n+2)==0)&(bits2_4(:,n+3)==1)&(bits2_4(:,n+4)==0));
k2=k2(1:150);
imagesc(bits2_4(k2,:))

return

figure
% k3=find((bits3_4(:,n+5)==1)&(bits3_4(:,n+0)==1)&(bits3_4(:,n+1)==0)&(bits3_4(:,n+2)==0)&(bits3_4(:,n+3)==1)&(bits3_4(:,n+4)==0));
k3=find((bits3_4(:,n+0)==1)&(bits3_4(:,n+1)==0)&(bits3_4(:,n+2)==0)&(bits3_4(:,n+3)==1)&(bits3_4(:,n+4)==0));
k3=k3(1:150);
imagesc(bits3_4(k3,:))

figure
imagesc(bits3_4(k1,:)-bits4_4(k2,:))

figure
imagesc(bits3_4(k3,:)-bits1_4(k1,:))

% save -mat bits2210.mat bits*
