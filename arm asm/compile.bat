@echo off
color 0a
arm-elf-as.exe -EB -mapcs-32 -mcpu=arm7tdmi test.s
extract.exe