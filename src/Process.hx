package;
#if sys
import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/**
 * ...
 * @author 
 */
class Process
{

	public static function writeTitles()
	{
		var titles = File.getContent("data/titles.txt");
		
		trace("a");
		
		var json = Json.parse(titles);
		var apps:Array<Dynamic> = json.applist.apps;
		
		trace("b");
		
		var appids = [];
		var i = 0;
		for (app in apps){
			
			var meta = FileSystem.exists("data/apps/" + app.appid + ".txt") ? 
				File.getContent("data/apps/" + app.appid + ".txt") : "";
				
			if (meta != "" && meta != null && meta.length >= 500){
				var appJson:Dynamic = Json.parse(meta);
				
				var obj:Dynamic = null;
				try{
					var fields = Reflect.fields(appJson);
					obj = Reflect.field(appJson, fields[0]);
				}catch (msg:Dynamic){
					trace("Msg = " + msg);
				}
				
				if (obj != null)
				{
					var data = obj.data;
					var type = data.type;
					if (type == "game"){
						appids.push(app.appid);
					}
				}
			}
			
			if (i > 0 && i % 100 == 0) {
				trace(i + " / " + apps.length);
			}
			i++;
		}
		
		trace("appids = " + appids.length);
		
		var str = appids.join("\n");
		File.saveContent("games.txt", str);
	}
}
#end
