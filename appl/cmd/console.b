implement ZaberConsole;

include "sys.m";
include "draw.m";
include "daytime.m";
include "lock.m";
include "tk.m";
include "tkclient.m";
include "arg.m";

include "zaber.m";

sys: Sys;
draw: Draw;
	Image, Font, Rect, Display: import draw;
daytime: Daytime;
tk: Tk;
tkclient: Tkclient;

zaber: Zaber;
	Instruction, Port: import zaber;

ZaberConsole: module {
	init: fn(ctxt: ref Draw->Context, argv: list of string);
};

dflag := 0;

init(ctxt: ref Draw->Context, argv: list of string)
{
	sys = load Sys Sys->PATH;
	draw = load Draw Draw->PATH;
	tk = load Tk Tk->PATH;
	tkclient = load Tkclient Tkclient->PATH;
	tkclient->init();
	daytime = load Daytime Daytime->PATH;
	
	zaber = load Zaber Zaber->PATH;
	zaber->init();

	arg := load Arg Arg->PATH;
	arg->init(argv);
	arg->setusage(arg->progname()+" [-d] path");
	while((c := arg->opt()) != 0)
		case c {
		'd' =>	dflag++;
		* =>	arg->usage();
		}
	
	argv = arg->argv();
	if(argv == nil)
		arg->usage();
	
	while(argv != nil) {
		path: string;
		path = hd argv;
		argv = tl argv;
		if(path != nil) {
			p : ref Port;
			p = zaber->open(path);
			if(p.data != nil)
				spawn window(ctxt, p);
		}
	}
}

window(ctxt: ref Draw->Context, p: ref Zaber->Port)
{
	sys->print("port: %s\n", p.local);
	zaber->close(p);
}
