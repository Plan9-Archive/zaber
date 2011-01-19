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

	# b2i & i2b
	b := zaber->i2b(-1);
	sys->print("i2b: %d %s\n", -1, dump(b));
	sys->print("b2i: %s %d\n", dump(b), zaber->b2i(b));
	
	b = zaber->i2b(32);
	sys->print("i2b: %d %s\n", 32, dump(b));
	sys->print("b2i: %s %d\n", dump(b), zaber->b2i(b));

	b = zaber->i2b(-32);
	sys->print("i2b: %d %s\n", -32, dump(b));
	sys->print("b2i: %s %d\n", dump(b), zaber->b2i(b));

	# firmware
	i := zaber->Instruction.new(0, Zaber->Cversion, Zeros);
	write(tls, i);
	r := read(tls);
	r = read(tls);
	r = read(tls);
	r = read(tls);

	a := array of byte "hola";
	i = zaber->Instruction.new(1, Zaber->Cecho, a);
	write(tls, i);
	r = read(tls);
	
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

read(p: ref Zaber->Port): ref Zaber->Instruction
{
	r := zaber->readreply(p, 10);
	if(r != nil)
		sys->print("RX <- %s\n", dump(r.bytes()));
	return r;
}

write(p: ref Zaber->Port, i: ref Zaber->Instruction)
{
	sys->print("TX -> %s\n", dump(i.bytes()));
	p.write(i);
}

dump(b: array of byte): string
{
	s := "";
	for(i:=0; i<len b; i++)
		s = sys->sprint("%s %d", s, int(b[i]));
	s = sys->sprint("%s %s", s, string(b[2:]));
	return s;
}
