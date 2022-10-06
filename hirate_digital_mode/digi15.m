pkg load signal

load digital15.mat   % code index +1 since index starting at 0 and matlab at 1
u=angle(xvals16.*exp(-j*unwrap(angle(xvals16)*2)/2)); % remove phase fluctuation
bits=floor(length(u)/250);                            % number of sentences
k=find(u<-2);u(k)=u(k)+2*pi;                          % 2pi phase addition
k=find(u<=1);u(k)=0;                                  % threshold
k=find(u>1);u(k)=1;

output=zeros(1,length(u)-1);          % remove differential encoding
for k=1:length(u)-1
  if (u(k)==u(k+1)) output(k)=1; else output(k)=0; end
end

sentences=(reshape(output(1:250*bits),250,bits)); % 250 bits/second, 1 message/second
imagesc(sentences')

motif=([1 0 1 1 0 1 0 1 1 1 ]); % LTFB SATRE ID=727
x=(xcorr(output-mean(output),motif-mean(motif)));
k=find(abs(x)>2.1);
diff(k)
figure
plot(x(floor(length(x)/2:end)))

% bits=sentences(216-35+1:240,:)';
bits=sentences';
save -text bits.txt bits
