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
#	RESET := array[6] of { * => byte 0};
#	write(wfd, RESET);
#	sys->sleep(200);

	# firmware
	i := zaber->Instruction.new(0, Zaber->Cversion, Zeros);
	write(tls, i);
	read(tls);

	a := array of byte "hola";
	i = zaber->Instruction.new(1, Zaber->Cecho, a);
	write(tls, i);
	read(tls);
	
	# dev id
	i = zaber->Instruction.new(0, Zaber->Cdeviceid, Zeros);
	write(tls, i);
	read(tls);
	
	i = zaber->Instruction.new(2, Zaber->Cdeviceid, Zeros);
	write(tls, i);
	read(tls);

	# home
	i = zaber->Instruction.new(0, Zaber->Chome, Zeros);
	write(tls, i);
	sys->sleep(200);
	read(tls);

	zaber->close(tls);
}

read(p: ref Zaber->Port)
{
	t := 1;
	while(t) {
		sys->sleep(10);
		a := zaber->getreply(p, 1);
		if(a == nil || len a == 0)
			t = 0;
		else
			sys->print("RX <- %s\n", dump(a[0].bytes()));
	}
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
