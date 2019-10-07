package;
import haxe.Http;

/**
 * ...
 * @author 
 */
class LinesIndex
{
	private static var all:Map<String,LinesIndex> = new Map<String,LinesIndex>();
	
	private var path:String;
	private var ranges:Array<LinesRange>;
	private var ready = false;
	private var fileLines:Map<String,String>;
	
	private var requestAppids:Array<String>;
	private var requestCallbacks:Array<String->Void>;
	
	public static function lines(path:String, file:String, appid:String, callback:Array<String>->Void)
	{
		if (!all.exists(path + file)){
			var li = new LinesIndex(path, file);
			all.set(path + file, li);
		}
		var li:LinesIndex = all.get(path + file);
		li.getInfo(appid, function(str:String){
			if (str != "" && str != null){
				callback(str.split(","));
			}else{
				callback([]);
			}
		});
	}
	
	
	public static function indexedLines(path:String, appid:String, callback:Array<String>->Void)
	{
		if (!all.exists(path)){
			var li = new LinesIndex(path, "index.tsv");
			all.set(path, li);
		}
		var li:LinesIndex = all.get(path);
		li.getInfo(appid, function(str:String){
			if (str != "" && str != null){
				callback(str.split(","));
			}else{
				callback([]);
			}
		});
	}
	
	public function new(path:String, file:String) 
	{
		this.path = path;
		this.ranges = [];
		this.requestCallbacks = [];
		this.requestAppids = [];
		this.ready = false;
		if (file.indexOf("index.") != -1){
			loadIndex(file);
		}else{
			load(file);
		}
	}
	
	private function load(file:String)
	{
		var http = new Http(path + file);
		http.onData = function(str:String){
			var start = -1;
			var end = -1;
			fileLines = new Map<String,String>();
			var lines = str.split("\n");
			for (line in lines){
				if (line == "" || line == null) continue;
				var cells = line.split("\t");
				if(cells.length >= 2){
					var appid = cells[0];
					var info = cells[1];
					fileLines.set(appid, info);
				}
			}
			onReady();
		}
		http.onStatus = function(i:Int){
			if (i != 200){
				trace("status = " + i + " file = " + path+file);
			}
		}
		http.onError = function(error:Dynamic){
			trace("error = " + error);
		}
		http.request();
	}
	
	private function loadIndex(file:String)
	{
		var http = new Http(path + file);
		http.onData = function(str:String){
			var lines = str.split("\n");
			for (line in lines){
				if (line == "" || line == null) continue;
				var cell = line.split("\t");
				if (cell.length >= 2){
					var start = Std.parseInt(cell[0]);
					var end = Std.parseInt(cell[1]);
					ranges.push(new LinesRange(start, end, path));
				}
			}
			onReady();
		}
		http.onStatus = function(i:Int){
			if (i != 200){
				trace("status = " + i + " file = " + path+file);
			}
		}
		http.onError = function(error:Dynamic){
			trace("error = " + error);
		}
		http.request();
	}
	
	private function onReady(){
		ready = true;
		for (i in 0...requestAppids.length){
			getInfo(requestAppids[i], requestCallbacks[i]);
		}
		requestCallbacks = null;
		requestAppids = null;
	}
	
	public function getInfo(appid:String, callback:String->Void)
	{
		if (!ready){
			requestAppids.push(appid);
			requestCallbacks.push(callback);
			return;
		}
		
		if (fileLines != null && fileLines.exists(appid)){
			callback(fileLines.get(appid));
			return;
		}
		
		var i:Int = Std.parseInt(appid);
		var found = false;
		for (range in ranges){
			if (range.test(i)){
				range.find(i, callback);
				found = true;
			}
		}
		if (!found){
			callback("");
		}
	}
}

class LinesRange
{
	public var low:Int;
	public var high:Int;
	public var lines:Map<String,String>;
	public var loaded:Bool = false;
	public var path:String;
	
	public function new(low:Int, high:Int, path:String)
	{
		this.path = path;
		this.low = low;
		this.high = high;
		lines = new Map<String,String>();
	}
	
	public function test(i:Int)
	{
		if (i >= low && i <= high){
			return true;
		}
		return false;
	}
	
	public function find(i:Int, callback:String->Void)
	{
		if (loaded){
			callback(lines.get(Std.string(i)));
		}else {
			load(
				function(b:Bool){
					if (b){
						callback(lines.get(Std.string(i)));
					}else{
						callback("");
					}
				}
			);
		}
	}
	
	public function load(callback:Bool->Void){
		var range = path + low + "_" + high + ".tsv";
		var http = new Http(range);
		http.onData = function(str:String){
			loadData(str);
			callback(true);
		}
		http.onStatus = function(i:Int){
			if (i != 200) {
				trace("status = " + i + " file = " + range);
				callback(false);
			}
		}
		http.onError = function(err:Dynamic){
			trace("error = " + err);
			callback(false);
		}
		http.request();
	}
	
	private function loadData(data:String)
	{
		var data = data.split("\n");
		for (line in data){
			var cells = line.split("\t");
			var key = cells[0];
			var info = cells[1];
			lines.set(key, info);
		}
		loaded = true;
	}
}