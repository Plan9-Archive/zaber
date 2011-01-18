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

Cmds: adt {
	code: int;
	text: string;
};

# version 5.xx commands
cmds: array of Cmds = array[] of {
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

Errors: adt {
	code: int;
	text: string;
};

errors: array of Errors = array[] of {
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
