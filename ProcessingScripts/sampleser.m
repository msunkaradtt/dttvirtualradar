clc
clear all
close all

tcpipServer = tcpserver("localhost",55000);

write(client,"helloworld","string")
read(tcpipServer,10,'string')

flush(tcpipServer)