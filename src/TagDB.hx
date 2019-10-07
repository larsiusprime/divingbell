package;
import haxe.Timer;

/**
 * ...
 * @author 
 */
class TagDB
{
	var gems:Map<String,TagEntries>;
	var overall:Map<String,TagEntries>;
	var weakTags:Array<String>;
	var tagToCategories:Map<String,Array<String>>;
	var appidToTags:Map<String,Array<String>>;
	var tagList:Array<String>;
	var tagFancyList:Array<String>;
	
	public function new()
	{
		gems = new Map<String,TagEntries>();
		overall = new Map<String,TagEntries>();
	}
	
	public function unfixTag(str:String):String
	{
		var i:Int = tagList.indexOf(str);
		if (i == -1) return str;
		return tagFancyList[i];
	}
	
	private function processTagCategories(callback:Void->Void){
		Get.file("data/v2/tags/categories.tsv", function(data:String){
			tagToCategories = new Map<String,Array<String>>();
			weakTags = [];
			var lines = data.split("\n");
			for (line in lines){
				var cells = line.split("\t");
				if (cells != null && cells.length >= 2){
					var tag = cells[0];
					var categories = cells[1].split(",");
					if (categories.indexOf("weak") != -1){
						weakTags.push(tag);
					}
					tagToCategories.set(tag, categories);
				}
			}
			callback();
		});
	}
	
	public function getTagProfile(tags:Array<String>, callback:Map<String,Array<String>>->Void)
	{
		if (tagToCategories == null){
			processTagCategories(function(){
				getTagProfile(tags, callback);
			});
			return;
		}
		var profile = new Map<String,Array<String>>();
		if (tags == null){
			callback(profile);
			return;
		}
		for (str in tags){
			var tag = str;
			var cats = tagToCategories.get(tag);
			if (cats != null){
				for (cat in cats){
					if (profile.exists(cat) == false){profile.set(cat, []); }
					var list = profile.get(cat);
					/*isWeak(tag, function(b:Bool){
						if(!b){
							list.push(tag);
						}
					});*/
					list.push(tag);
				}
			}
		}
		callback(profile);
	}
	
	public function isWeakQuick(tag:String):Bool
	{
		return switch(tag){
			case "action", "adventure", "indie": true;
			default: false;
		}
	}
	
	public function isWeak(tag:String, callback:Bool->Void)
	{
		if (weakTags == null){
			processTagCategories(function(){
				callback(weakTags.indexOf(tag) != -1);
			});
		}else{
			callback(weakTags.indexOf(tag) != -1);
		}
	}
	
	public function getTagsForApp(appid:String, callback:Array<String>->Void)
	{
		if (appidToTags == null){
			processAppidTags(function(){
				var arr = appidToTags.get(appid);
				if (arr != null) arr = arr.copy();
				if (arr == null) arr = [];
				callback(arr);
			});
		}else{
			var arr = appidToTags.get(appid);
			if (arr != null) arr = arr.copy();
			if (arr == null) arr = [];
			callback(arr);
		}
	}
	
	private function processAppidTags(callback:Void->Void){
		var time = Timer.stamp();
		Get.file("data/v2/tags/tags.tsv", function(tagData:String){
			Get.file("data/v2/tags/all.tsv", function(allData:String){
				appidToTags = new Map<String,Array<String>>();
				var tagLines = tagData.split("\n");
				tagList = [];
				tagFancyList = [];
				for (line in tagLines){
					var bits = line.split("\t");
					tagList.push(bits[0]);
					tagFancyList.push(bits[1]);
				}
				
				var lines = allData.split("\n");
				for (lines in lines){
					var cells = lines.split("\t");
					if(cells != null && cells.length > 0)
					{
						var appid = cells[0];
						var tagStr = cells[1];
						if(tagStr != "" && tagStr != null){
							var tags = tagStr.split(",");
							var appTags = [];
							for (tag in tags){
								if (tag == null || tag == "") continue;
								var tagi:Int = Std.parseInt(tag);
								var tagValue:String = tagList[tagi];
								appTags.push(tagValue);
							}
							appidToTags.set(appid, appTags);
						}
					}
				}
				callback();
			});
		});
	}
	
	public function getAllCategories(callback:Map<String,Array<String>>->Void)
	{
		if (tagToCategories == null){
			processTagCategories(function(){
				callback(tagToCategories);
			});
		}else{
			callback(tagToCategories);
		}
	}
	
	public function getCategories(tag:String, callback:Array<String>->Void)
	{
		if (tagToCategories == null){
			processTagCategories(function(){
				callback(tagToCategories.get(tag));
			});
		}else{
			callback(tagToCategories.get(tag));
		}
	}
	
	public function getAppsWithTags(tags:Array<String>, callback:Array<String>->Void)
	{
		trace("getAppsWithTags(" + tags + ")");
		var count = tags.length;
		var results = [];
		for (tag in tags){
			
			if (isWeakQuick(tag)) {
				count--;
				if (count <= 0){
					callback(results);
				}
				continue;
			}
			
			Get.file("data/v2/tags/index/" + tag + ".tsv", function(data:String){
				var appids = data.split("\n");
				for (app in appids){
					if (results.indexOf(app) == -1){
						results.push(app);
					}
				}
				count--;
				if (count <= 0){
					callback(results);
				}
			});
		}
	}
	
	public function getEntries(tag:String, count:Int, isGems:Bool, callback:Array<TagEntry>->Void)
	{
		var theEntries:Map<String,TagEntries> = isGems ? gems : overall;
		if (theEntries.exists(tag) == false){
			Get.file("data/v2/tags/" + (isGems ? "gems_" : "overall_") + tag + ".tsv", function(data:String){
				if (data != null && data != ""){
					var theEntries = isGems ? addGemEntry(tag, data) : addEntry(tag, data);
					_getEntries(tag, count, theEntries, callback);
				}
			});
		}else{
			_getEntries(tag, count, theEntries.get(tag), callback);
		}
	}
	
	private function addGemEntry(tag:String, data:String):TagEntries{
		var result = new TagEntries(tag, data);
		gems.set(tag, result);
		return result;
	}
	
	private function addEntry(tag:String, data:String):TagEntries{
		var result = new TagEntries(tag, data);
		overall.set(tag, result);
		return result;
	}
	
	private function _getEntries(tag:String, count:Int, theEntries:TagEntries, callback:Array<TagEntry>->Void)
	{
		var results = [];
		var i = 0;
		if (theEntries != null){
			for (entry in theEntries.list){
				results.push(entry);
				i++;
				if (i >= count){
					break;
				}
			}
		}
		callback(results);
	}
}

class TagEntries
{
	public var tag:String;
	public var list:Array<TagEntry>;
	
	public function new(tag:String, data:String)
	{
		this.tag = tag;
		list = [];
		var lines:Array<String> = data.split("\n");
		for (line in lines){
			var cells = line.split("\t");
			if (cells.length >= 2){
				var appid = cells[0];
				var score = Std.parseFloat(cells[1]);
				if (Math.isNaN(score)){
					score = 0.5;
				}
				var entry = new TagEntry(appid, score);
				list.push(entry);
			}
		}
		
		list.sort(function(a:TagEntry, b:TagEntry):Int{
			if (a.score > b.score) return -1;
			if (a.score < b.score) return  1;
			return 0;
		});
	}
}

class TagEntry
{
	public var appid:String;
	public var score:Float;
	
	public function new(appid:String, score:Float){
		this.appid = appid;
		this.score = score;
	}
}