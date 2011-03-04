implement ZaberConsole;

include "sys.m";
include "draw.m";
include "daytime.m";
include "lock.m";
include "string.m";
include "tk.m";
include "tkclient.m";
include "arg.m";

include "zaber.m";

sys: Sys;
	sprint: import sys;
draw: Draw;
	Image, Font, Point, Rect, Display: import draw;
daytime: Daytime;
str: String;
tk: Tk;
tkclient: Tkclient;

zaber: Zaber;
	Instruction, Port: import zaber;

UP:			con 57362;			# up arrow, 0xE012
DOWN:		con 57363;			# down arrow, 0xE013
PGUP:		con 57366;			# page up, 0xE016
PGDOWN:		con 57367;			# page down, 0xE017

ZaberConsole: module {
	init:	fn(ctxt: ref Draw->Context, argv: list of string);
};

dflag := 0;
pid : int;

p: ref Zaber->Port;
x: int;
y: int;

t: ref Tk->Toplevel;
wmctl: chan of string;

tkcmds := array[] of {
	"frame .f",
	"canvas .c -bg black",
	
	"label .l.pos -width 128 -text {(0, 0)}",
	"entry .e.x -width 60 -bg white",
	"entry .e.y -width 60 -bg white",
	
	"bind .c <ButtonRelease-1> {send cmd 0 %x %y}",
	"bind .c <ButtonRelease-2> {send cmd 0 %x %y}",
	"bind .c <Button-1> {send cmd 1 %x %y}",
	"bind .c <Button-2> {send cmd 2 %x %y}",
	"bind .e.x <Key {send numbers {%A} .e.x}",
	"bind .e.y <Key {send numbers {%A} .e.y}",
	
	"pack .f -fill both -expand 1",
	"grid .l.pos -in .f -row 0 -column 0",
	"grid .e.x -in .f -row 0 -column 1 -sticky w",
	"grid .e.y -in .f -row 1 -column 0 -sticky ne",
	"grid .c -in .f -row 1 -column 1",
};

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	str = load String String->PATH;
	tk = load Tk Tk->PATH;
	tkclient = load Tkclient Tkclient->PATH;
	tkclient->init();
	daytime = load Daytime Daytime->PATH;
	
	zaber = load Zaber Zaber->PATH;
	zaber->init();

	path := "tcp!iolan!zaber";
	x = 65663;
	y = 65663;
	
	arg := load Arg Arg->PATH;
	arg->init(argv);
	arg->setusage(arg->progname()+" [-d] [path]");
	while((c := arg->opt()) != 0)
		case c {
		'd' =>	dflag++;
		* =>	arg->usage();
		}
	
	argv = arg->argv();
	if(argv != nil)
		path = hd argv;

	if(path != nil) {
		p = zaber->open(path);
		if(p.data != nil)
			spawn window(ctxt);
	}
}

window(ctxt: ref Draw->Context)
{
	sys->print("port: %s\n", p.local);
	
	pid = sys->pctl(sys->NEWPGRP | Sys->FORKNS, nil);
	(t, wmctl) = tkclient->toplevel(ctxt, "", "zaber console", Tkclient->Appl);
	
	cmdch := chan of string;
	tk->namechan(t, cmdch, "cmd");
	for(i := 0; i < len tkcmds; i++)
		tkcmd(tkcmds[i]);

	tkcmd(".c configure -width 260 -height 260");

	tchan := chan of int;
	spawn timer(tchan, 250);
	
	numbers := chan of string;
	tk->namechan(t, numbers, "numbers");

	tkclient->onscreen(t, nil);
	tkclient->startinput(t, "kbd"::"ptr"::nil);

	r := zaber->Instruction.newwithval(0, Zaber->Cposition, 0);
	p.write(r);
	
	main: for(;;) alt {
		s := <-t.ctxt.kbd =>
			tk->keyboard(t, s);
		s := <-t.ctxt.ptr =>
			tk->pointer(t, *s);
		s := <-t.ctxt.ctl or
		s = <-t.wreq =>
			tkclient->wmctl(t, s);
		menu :=  <-wmctl =>
			if(menu == "exit")
				quit();
			tkclient->wmctl(t, menu);
		
		c := <-cmdch =>
			# sys->print("%s\n", c);
			# max microstep: 131327
			(nil, toks) := sys->tokenize(c, " ");
			pnt := Point(int hd tl toks, int hd tl tl toks);
			x1 := real pnt.x * 505.1038;
			y1 := real pnt.y * 505.1038;
			xd := zaber->Instruction.newwithval(1, Zaber->Cmoveabsolute, int(x1));
			yd := zaber->Instruction.newwithval(2, Zaber->Cmoveabsolute, int(y1));
			p.write(xd);
			p.write(yd);

		s := <-numbers =>
			numericfield(s);
		
		j := <-tchan =>
			r = zaber->readreply(p, 1);
			if(r != nil)
				processreply(r);
	}
	
	zaber->close(p);
}

numericfield(s: string)
{
	v, val : int;
	(c, e) := str->splitstrr(s, "} ");
	char := c[1];
	
	case char {
	'0' to '9' or '.' or '-' or 'e' or 'E' =>
		tkcmd(sprint("%s delete sel.first sel.last", e));
		tkcmd(sprint("%s insert insert %s", e, c));
		tkcmd(sprint("%s see insert;update", e));
		return;
	'\n' =>
		val = 0;
	'\t' =>
		tkcmd(sprint("%s selection clear", e));
		tkcmd("focus next;update");
		return;
	UP =>
		val = 1000;
	DOWN =>
		val = -1000;
	PGUP =>
		val = 10000;
	PGDOWN =>
		val = -10000;
	* =>
		return;
	}
	
	sval := int tkcmd(e+" get");
	tkcmd(e+" delete 0 end");
	tkcmd(sprint("%s insert insert {%d}", e, sval+val));
	v = sval + val;
	r : ref Instruction;
	case e {
	".e.x" =>
		r = zaber->Instruction.newwithval(1, Zaber->Cmoveabsolute, v);
	".e.y" =>
		r = zaber->Instruction.newwithval(2, Zaber->Cmoveabsolute, v);
	}
	if(r != nil)
		p.write(r);
}

processreply(r: ref Zaber->Instruction)
{
	if(dflag)
		sys->print("RX <-\n%s\n", r.dump());
	
	case r.cmd {
	Zaber->Chome or
	Zaber->Cmovetracking or
	Zaber->Climitactive or
	Zaber->Cmanualmove or
	Zaber->Cstoredposition or
	Zaber->Cmovetostoredpos or
	Zaber->Cmoveabsolute or
	Zaber->Cmoverelative or
	Zaber->Cstop or
	Zaber->Csetcurrentposition or
	Zaber->Cposition =>
		v := r.value();
		if(r.id == 1)
			x = v;
		if(r.id == 2)
			y = v;
		tkcmd(sprint(".l.pos configure -text {(%d, %d)}", x, y));
	* =>
		sys->print("%s\n", r.dump());
	}
	
	tkcmd("update");
}

quit()
{
	zaber->close(p);
	killgrp(pid);
	exit;
}


kill(pid: int)
{
	if(pid >= 0 && (fd := sys->open(sprint("/prog/%d/ctl", pid), Sys->OWRITE)) != nil)
		sys->fprint(fd, "kill");
}

killgrp(pid: int)
{
	if((fd := sys->open(sprint("/prog/%d/ctl", pid), Sys->OWRITE)) != nil)
		sys->fprint(fd, "killgrp");
}

timer(tick: chan of int, ms: int)
{
	for(;;){
		sys->sleep(ms);
		tick <-= 1;
	}
}


tkcmd(s: string): string
{
	r := tk->cmd(t, s);
	if(r != nil && r[0] == '!')
		sys->print("tkcmd: %q: %s", s, r);
	return r;
}
