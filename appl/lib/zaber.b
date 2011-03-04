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

# version 5.xx commands
cmds: array of Code = array[] of {
	(0, "Reset"),
	(1, "Home"),
	(2, "Renumber"),
	(8, "Move tracking"),
	(9, "Limit active"),
	(10, "Manual move tracking"),
	(16, "Store current position"),
	(17, "Return stored position"),
	(18, "Move to stored position"),
	(20, "Move absolute"),
	(21, "Move relative"),
	(22, "Move at constant speed"),
	(23, "Stop"),
	(35, "Read/write memory"),
	(36, "Restore settings"),
	(37, "Set microstep resolution"),
	(38, "Set running current"),
	(39, "Set hold current"),
	(40, "Set device mode"),
	(42, "Set target speed"),
	(43, "Set acceleration"),
	(44, "Set maximum range"),
	(45, "Set current position"),
	(46, "Set maximum relative move"),
	(47, "Set home offset"),
	(48, "Set alias number"),
	(49, "Set lock state"),
	(50, "Return device id"),
	(51, "Return firmware version"),
	(52, "Return power supply voltage"),
	(53, "Return setting"),
	(54, "Return status"),
	(55, "Echo data"),
	(60, "Return current position"),
	(255, "Error"),
};

errors: array of Code = array[] of {
	(1, "Cannot Home"),
	(2, "Device Number Invalid"),
	(14, "Voltage Low"),
	(15, "Voltage High"),
	(18, "Stored Position Invalid"),
	(20, "Absolute Position Invalid"),
	(21, "Relative Position Invalid"),
	(22, "Velocity Invalid"),
	(36, "Peripheral Id Invalid"),
	(37, "Resolution Invalid"),
	(38, "Run Current Invalid"),
	(39, "Hold Current Invalid"),
	(40, "Mode Invalid"),
	(41, "Home Speed Invalid"),
	(42, "Speed Invalid"),
	(43, "Acceleration Invalid"),
	(44, "Maximum Range Invalid"),
	(45, "Current Position Invalid"),
	(46, "Maximum Relative Move Invalid"),
	(47, "Offset Invalid"),
	(48, "Alias Invalid"),
	(49, "Lock State Invalid"),
	(50, "Device Id Unknown"),
	(53, "Setting Invalid"),
	(64, "Command Invalid"),
	(255, "Busy"),
	(1600, "Save Position Invalid"),
	(1601, "Save Position Not Homed"),
	(1700, "Return Position Invalid"),
	(1800, "Move Position Invalid"),
	(1801, "Move Position Not Homed"),
	(2146, "Relative Position Limited"),
	(3600, "Settings Locked"),
	(4008, "Disable Auto Home Invalid"),
	(4010, "Bit 10 Invalid"),
	(4012, "Home Switch Invalid"),
	(4013, "Bit 13 Invalid"),
};

statuses: array of Code = array[] of {
	(0, "Idle"),
	(1, "Executing a home instruction"),
	(10, "Executing a manual move"),
	(20, "Executing a move absolute instruction"),
	(21, "Executing a move relative instruction"),
	(22, "Executing a move at constant speed instruction"),
	(23, "Executing a stop instruction"),
};


Instruction.new(d, c: int, b: array of byte): ref Instruction
{
	ni : ref Instruction;
	valid := 0;
	for(i:=0; i< len cmds; i++) {
		if(cmds[i].code == c) {
			valid = 1;
			break;
		}
	}
	if(valid && len b == 4)
		ni = ref Instruction(d, c, b);
	return ni;
}

Instruction.newwithval(d, c, v: int): ref Instruction
{
	ni: ref Instruction;
	valid := 0;
	for(i:=0; i< len cmds; i++) {
		if(cmds[i].code == c) {
			valid = 1;
			break;
		}
	}
	if(valid) {
		b := Instruction.valuebytes(v);
		ni = ref Instruction(d, c, b);
	}
	
	return ni;
}

Instruction.bytes(inst: self ref Instruction): array of byte
{
	b := array[6] of byte;
	b[0] = byte inst.id;
	b[1] = byte inst.cmd;
	for(i := 0; i < len inst.data; i++)
		b[2+i] = inst.data[i];
	return b;
}

Instruction.value(inst: self ref Instruction): int
{
	if(len inst.data != 4)
		return -1;
	d := inst.data;
	v := 256**3 * int(d[3]) + 256**2 * int(d[2]) + 256 * int(d[1]) + int(d[0]);
	if(int(d[3]) > 127)
		v = v - 256**4;
	return v;
}

Instruction.valuebytes(v: int): array of byte
{
	b := array[4] of byte;
	if(v < 0)
		v = 256**4 + v;
	b[3] = byte(v / 256**3);
	v = v - 256**3 * int(b[3]);
	b[2] = byte(v / 256**2);
	v = v - 256**2 * int(b[2]);
	b[1] = byte(v / 256);
	v = v - 256;
	b[0] = byte(v);
	return b;
}

Instruction.dump(inst: self ref Instruction): string
{
	s := "";
	s = s + sys->sprint("(id \"%d\")\n", inst.id);
	s = s + sys->sprint("(cmd (%d \"%s\"))\n", inst.cmd, codetext(cmds, inst.cmd));
	s = s + sys->sprint("(data (\"%s\" %d))", hexdump(inst.data), inst.value());
	if(inst.cmd == Cerror)
		s = s + sys->sprint("\n(error (%d \"%s\"))", inst.value(), codetext(errors, inst.value()));
	return s;
}

Device.write(d: self ref Device, c: int, data: array of byte): int
{
	i := ref Instruction(d.id, c, data);
	return d.port.write(i);
}

Port.write(p: self ref Port, i: ref Instruction): int
{
	r := 0;
	
	b := i.bytes();
	p.wrlock.obtain();
	r = sys->write(p.data, b, len b);
	if(i.cmd == Crenumber)
		sys->sleep(500);
	p.wrlock.release();

	return r;
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
	newport.rdlock = Semaphore.new();
	newport.wrlock = Semaphore.new();
	newport.local = path;
	newport.pid = 0;
	
	openport(newport);
	reading(newport);
	
	return newport;
}

# prepare device port
openport(p: ref Port)
{
	if(p==nil) {
		raise "fail: port not initialized";
		return;
	}
	
	p.data = nil;
	p.ctl = nil;
	
	if(p.local != nil) {
		if(str->in('!', p.local)) {
			(ok, net) := sys->dial(p.local, nil);
			if(ok == -1) {
				raise "can't open "+p.local;
				return;
			}

			p.ctl = sys->open(net.dir+"/ctl", Sys->ORDWR);
			p.data = sys->open(net.dir+"/data", Sys->ORDWR);
		} else {
			p.ctl = sys->open(p.local+"ctl", Sys->ORDWR);
			p.data = sys->open(p.local, Sys->ORDWR);
		}
	}
	
	p.avail = nil;
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
	p.rdlock.obtain();
	if(len p.avail != 0) {
		if((n*6) > len p.avail)
			n = len p.avail / 6;
		b = p.avail[0:(n*6)];
		p.avail = p.avail[(n*6):];
	}
	p.rdlock.release();

	a : array of ref Instruction;
	if(len b) {
		a = array[n] of { * => ref Instruction};
		for(j:=0; j<n; j++) {
			i := a[j];
			i.id = int(b[(j*6)]);
			i.cmd = int(b[(j*6)+1]);
			i.data = b[(j*6)+2:(j*6)+6];
		}
	}
	return a;
}

# read until timeout or result is returned
readreply(p: ref Port, ms: int): ref Instruction
{
	if(p == nil)
		return nil;
	
	limit := 60000;			# arbitrary maximum of 60s
	r : ref Instruction;
	for(start := sys->millisec(); sys->millisec() <= start+ms;) {
		a := getreply(p, 1);
		if(len a == 0) {
			if(limit--) {
				sys->sleep(1);
				continue;
			}
			break;
		}
		return a[0];
	}
	
	return r;
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
	
	buf := array[1] of byte;
	for(;;) {
		while((n := sys->read(p.data, buf, len buf)) > 0) {
			p.rdlock.obtain();
			if(len p.avail < Sys->ATOMICIO) {
				na := array[len p.avail + n] of byte;
				na[0:] = p.avail[0:];
				na[len p.avail:] = buf[0:n];
				p.avail = na;
			}
			p.rdlock.release();
		}
		# error, try again
		p.data = nil;
		p.ctl = nil;
		openport(p);
	}
}

# support fn
b2i(b: array of byte): int
{
	i := 0;
	if(len b == 4) {
		i = int(b[0])<<0;
		i |= int(b[1])<<8;
		i |= int(b[2])<<16;
		i |= int(b[3])<<24;
	}
	return i;
}

i2b(i: int): array of byte
{
	b := array[4] of byte;
	b[0] = byte(i>>0);
	b[1] = byte(i>>8);
	b[2] = byte(i>>16);
	b[3] = byte(i>>24);
	return b;
}

codetext(c: array of Code, id: int): string
{
	s := "";
	for(i:=0; i< len c; i++) {
		if(c[i].code == id) {
			s = c[i].text;
			break;
		}
	}
	return s;
}

# convenience
hexdump(data : array of byte): string
{
	s := "";
	for (i := 0; i < len data; i++)
		 s = s + sys->sprint(" %.2x", int data[i]);
	return s;
}

kill(pid: int)
{
	fd := sys->open("#p/"+string pid+"/ctl", Sys->OWRITE);
	if(fd == nil || sys->fprint(fd, "kill") < 0)
		sys->print("zaber: can't kill %d: %r\n", pid);
}
