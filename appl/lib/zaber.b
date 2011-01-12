implement Zaber;

include "sys.m";
include "dial.m";
include "string.m";

include "zaber.m";

sys: Sys;
dial: Dial;
str: String;

init()
{
	sys = load Sys Sys->PATH;
	dial = load Dial Dial->PATH;
	str = load String String->PATH;
}

open(path: string): ref Connection
{
	conn : ref Connection;

	if(path != nil) {
		conn = ref Connection(path, nil, nil);
		if(str->in('!', path)) {
			(ok, net) := sys->dial(path, nil);
			if(ok == -1)
				return nil;

			conn.rfd = sys->open(net.dir+"/data", Sys->OREAD);
			conn.wfd = sys->open(net.dir+"/data", Sys->OWRITE);
		} else {
			conn.rfd = sys->open(path, Sys->OREAD);
			conn.wfd = sys->open(path, Sys->OWRITE);
		}
	}

	return conn;
}


Instruction.new(d, c: int, b: array of byte): ref Instruction
{
	return ref Instruction(d, c, b);
}

Instruction.bytes(inst: self ref Instruction): array of byte
{
	b := array[6] of byte;
	b[0] = byte inst.id;
	b[1] = byte inst.com;
	for(i := 0; i < len inst.data; i++)
		b[2+i] = inst.data[i];
	return b;
}

Device.write(d: self ref Device, c: int, data: array of byte): int
{
	i := ref Instruction(d.id, c, data);
	return d.conn.write(i);
}

Connection.write(c: self ref Connection, i: ref Instruction): int
{
	b := i.bytes();
	return sys->write(c.wfd, b, len b);
}
