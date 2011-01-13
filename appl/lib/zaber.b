implement Zaber;

include "sys.m";
include "dial.m";
include "lock.m";
include "string.m";

include "zaber.m";

sys: Sys;
dial: Dial;
str: String;
lock: Lock;
	Semaphore: import lock;


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
	return d.port.write(i);
}

Port.write(p: self ref Port, i: ref Instruction): int
{
	b := i.bytes();
	return sys->write(p.data, b, len b);
}


init()
{
	sys = load Sys Sys->PATH;
	dial = load Dial Dial->PATH;
	str = load String String->PATH;
	lock = load Lock Lock->PATH;
	if(lock == nil)
		raise "fail: Couldn't load lock module";
	lock->init();
}

open(path: string): ref Port
{
	if(sys == nil) init();
	
	newport := ref Port;
	newport.lock = Semaphore.new();
	newport.local = path;
	newport.pid = 0;
	
	if(path != nil) {
		if(str->in('!', path)) {
			(ok, net) := sys->dial(path, nil);
			if(ok == -1)
				return nil;

			newport.ctl = sys->open(net.dir+"/ctl", Sys->ORDWR);
			newport.data = sys->open(net.dir+"/data", Sys->ORDWR);
		} else {
			newport.ctl = sys->open(path+"ctl", Sys->ORDWR);
			newport.data = sys->open(path, Sys->ORDWR);
		}
	}
	
	reading(newport);
	return newport;
}

# shut down reader (if any)
close(p: ref Port): ref Sys->Connection
{
	if(p == nil)
		return nil;
	
	if(p.pid != 0){
		kill(p.pid);
		p.pid = 0;
	}
	if(p.data == nil)
		return nil;
	c := ref sys->Connection(p.data, p.ctl, nil);
	p.ctl = nil;
	p.data = nil;
	return c;
}

getreply(p: ref Port, n: int): array of ref Instruction
{
	if(p==nil || n <= 0)
		return nil;

	b : array of byte;
	p.lock.obtain();
	if(len p.avail != 0) {
		if((n*6) > len p.avail)
			n = len p.avail / 6;
		b = p.avail[0:(n*6)];
		p.avail = p.avail[(n*6):];
	}
	p.lock.release();

	a : array of ref Instruction;
	if(len b) {
		a = array[n] of { * => ref Instruction};
		for(j:=0; j<n; j++) {
			i := a[j];
			i.id = int(b[(j*6)]);
			i.com = int(b[(j*6)+1]);
			i.data = b[(j*6)+2:(j*6)+6];
		}
	}
	return a;
}

send(p: ref Port, i: ref Instruction): int
{
	if(p == nil || i == nil || p.data == nil)
		return -1;
	
	return p.write(i);
}


reading(p: ref Port)
{
	if(p.pid == 0) {
		pidc := chan of int;
		spawn reader(p, pidc);
		p.pid = <-pidc;
	}
}

reader(p: ref Port, pidc: chan of int)
{
	pidc <-= sys->pctl(0, nil);
	
	buf := array[6] of byte;
	while((n := sys->read(p.data, buf, len buf)) > 0) {
		p.lock.obtain();
		if(len p.avail < Sys->ATOMICIO) {
			na := array[len p.avail + n] of byte;
			na[0:] = p.avail[0:];
			na[len p.avail:] = buf[0:n];
			p.avail = na;
		}
		p.lock.release();
	}
}

# convenience
kill(pid: int)
{
	fd := sys->open("#p/"+string pid+"/ctl", Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "kill") < 0)
		sys->print("zaber: can't kill %d: %r\n", pid);
}