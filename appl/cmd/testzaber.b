implement TestZaber;

include "sys.m";
include "draw.m";
include "lock.m";

include "zaber.m";

sys: Sys;
draw: Draw;

zaber: Zaber;
	Instruction, Port: import zaber;

TestZaber: module {
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

init(ctxt: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	
	zaber = load Zaber Zaber->PATH;
	zaber->init();
	
	tls := zaber->open("/dev/eia0");
	
	Zeros := array[4] of { * => byte 0};

	# firmware
	i := zaber->Instruction.new(0, Zaber->Cversion, Zeros);
	write(tls, i);
	read(tls);
	read(tls);
	read(tls);
	read(tls);

	a := array of byte "hola";
	i = zaber->Instruction.new(1, Zaber->Cecho, a);
	write(tls, i);
	read(tls);
	
	# dev id
	i = zaber->Instruction.new(0, Zaber->Cdeviceid, Zeros);
	write(tls, i);
	read(tls);
	read(tls);
	read(tls);
	read(tls);
	
	i = zaber->Instruction.new(2, Zaber->Cdeviceid, Zeros);
	write(tls, i);
	read(tls);

	# home
	i = zaber->Instruction.new(0, Zaber->Chome, Zeros);
	write(tls, i);
	sys->sleep(1000);
	read(tls);
	read(tls);
	read(tls);
	read(tls);

	zaber->close(tls);
}

read(p: ref Zaber->Port)
{
	r := zaber->readreply(p, 10);
	if(r != nil)
		sys->print("RX <- %s\n", dump(r.bytes()));
}

write(c: ref Zaber->Port, i: ref Zaber->Instruction)
{
	sys->print("TX -> %s\n", dump(i.bytes()));
	c.write(i);
	sys->sleep(10);
}

dump(b: array of byte): string
{
	s := "";
	for(i:=0; i<len b; i++)
		s = sys->sprint("%s %d", s, int(b[i]));
	s = sys->sprint("%s %s", s, string(b[2:]));
	return s;
}
