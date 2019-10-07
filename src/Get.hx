package;

import haxe.Http;
import haxe.Json;
import haxe.Timer;
import haxe.ds.ArraySort;
import haxe.io.Bytes;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.TimerEvent;
import openfl.text.TextField;
import openfl.text.TextFormatAlign;
import TagDB.TagEntries;
import TagDB.TagEntry;

/**
 * ...
 * @author 
 */
class Get
{
	private static var id2title:Map<String,String> = new Map<String,String>();
	private static var tagDB:TagDB = new TagDB();
	private static var gemScores:Map<String,Float>;
	private static var topScores:Map<String,Float>;
	private static var topAppsByGem:Array<String>;
	private static var topAppsByTop :Array<String>;
	private static var reviewScores:Map<String,{ratings:Int,posRatings:Int}>;
	
	private static inline var TOP_COUNT:Int = 2000;
	
	public static function unfixTag(str:String):String
	{
		return tagDB.unfixTag(str);
	}
	
	public static function fixTag(str:String):String
	{
		str = str.toLowerCase();
		var tokens = [",", "-", "'", "_"];
		for(token in tokens){
			str = StringTools.replace(str, token, "");
		}
		str = StringTools.replace(str, " ", "_");
		str = StringTools.replace(str, "&", "and");
		str = StringTools.replace(str, "+", "plus");
		return str;
	}
	
	public static function tagCategories(tag:String, callback:Array<String>->Void){
		tagDB.getCategories(tag, callback);
	}
	
	public static function isTagWeak(tag:String, callback:Bool->Void){
		tagDB.isWeak(tag, callback);
	}
	
	public static function file(fileName:String, callback:String->Void)
	{
		var http = new Http(fileName);
		http.onData = function(data:String){
			if (data == null) {
				return; 
			}
			callback(data);
		};
		http.onStatus = function(status:Int){
			if (status != 200){
				callback(null);
			}
		};
		http.onError = function(error:Dynamic){
			callback(null);
		};
		http.request();
	}
	
	
	public static function titles(callback:Array<String>->Array<String>->Void)
	{
		var http = new Http("data/v2/titles.tsv");
		http.onData = function(data:String){
			if (data == null) {
				return; 
			}
			var lines = data.split("\n");
			var appids:Array<String> = [];
			var names:Array<String> = [];
			for (line in lines){
				if (line == null || line == "") continue;
				var cells = line.split("\t");
				if(cells != null && cells.length >= 2){
					appids.push(cells[0]);
					names.push(cells[1]);
				}
			}
			callback(appids, names);
		};
		http.onStatus = function(status:Int){
			if (status != 200){
				callback(null,null);
			}
		};
		http.onError = function(error:Dynamic){
			callback(null,null);
		};
		http.request();
	}
	
	public static function details(appid:String, callback:Dynamic->Void)
	{
		var http = new Http("data/v2/app_details/"+appid+".txt");
		http.onData = function(data:String){
			if (data == null || data == "" || data.length < 500) {
				callback(null);
				return; 
			}
			var json = Json.parse(data);
			var fields = Reflect.fields(json);
			if (fields.length > 0){
				var obj = Reflect.field(json, fields[0]);
				var data = obj.data;
				tagsFor(appid, function(arr:Array<String>){
					Reflect.setField(data, "tags", arr.copy());
					reviews(appid, function(rData:{ratings:Int, posRatings:Int}){
						Reflect.setField(data, "ratings", rData.ratings);
						Reflect.setField(data, "posRatings", rData.posRatings);
						Reflect.setField(data, "ratingPercent", Std.int(100 * rData.posRatings / rData.ratings) + "%");
						callback(data);
					});
				});
			}
			else{
				callback(null);
			}
			
		};
		http.onStatus = function(status:Int){
			if (status != 200){
				callback(null);
			}
		};
		http.onError = function(error:Dynamic){
			callback(null);
		};
		http.request();
	}
	
	public static function imageRaw(url:String, callback:BitmapData->Void, count:Int=0)
	{
		var future = BitmapData.loadFromFile(url);
		future.onComplete(callback);
		future.onError(function(error:Dynamic){
			if (count < 3)
			{
				image(url, callback, count + 1);
			}
			else
			{
				callback(null);
			}
		});
	}
	
	public static function image(appid:String, callback:BitmapData->Void, count:Int=0)
	{
		var url = "https://steamcdn-a.akamaihd.net/steam/apps/" + appid + "/header.jpg";
		var future = BitmapData.loadFromFile(url);
		
		future.onComplete(callback);
		future.onError(function(error:Dynamic){
			var url = "data/v2/img/" + appid + ".jpg";
			future = BitmapData.loadFromFile(url);
			
			future.onComplete(callback);
			
			future.onError(function(error:Dynamic){
				var url = "data/v1/img/" + appid + ".jpg";
				var future = BitmapData.loadFromFile(url);
				
				future.onComplete(callback);
				future.onError(function(error:Dynamic){
					callback(null);
				});
			});
		});
	}
	
	private static function addEntry(list:MatchResults, other:MatchResults, exclude:Array<String>, max:Int, meta:Array<String>, metaLabel:String):Int
	{
		var max = Std.int(Math.min(max, other.appids.length));
		var count = 0;
		
		while (count < max && other.appids.length > 0){
			var value = other.shift();
			if (value == null) continue;
			if (list.appids.indexOf(value.appid) == -1 && exclude.indexOf(value.appid) == -1){
				list.add(value.appid, value.score, metaLabel);
				meta.push(metaLabel);
				count++;
			}
		}
		
		return count;
	}
	
	public static function more_mix(appid:String, exclude:Array<String>, callback:MatchResults->Void)
	{
		trace("more_mix(" + appid + ")");
		var results = new MatchResults();
		var meta = [];
		var remaining = 8;
		
		var picks = []; 
		var counts = [];
		
		for (i in 0...Main.RECOMMENDERS.length){
			var recommender = Main.RECOMMENDERS[i];
			picks.push(recommender.id);
			counts.push(recommender.count);
		}
		
		var finish = function(){
			callback(results.copy());
		};
		
		var processStuff = function(mapArrs:Map<String,MatchResults>){
			for (key in mapArrs.keys()){
				var pick = key;
				var max = remaining;
				var theArr = mapArrs.get(pick);
				
				var picki = picks.indexOf(pick);
				max = counts[picki];
				
				var added = addEntry(results, theArr, exclude, max, meta, pick);
				
				remaining -= added;
			}
			
			//Fill in any gaps first with noisy matches, then with more matches, to guarantee a full set
			if (remaining > 0){
				more(appid, exclude, function(newResults:MatchResults){
					remaining -= addEntry(results, newResults, exclude, remaining, meta, "more");
					if (remaining > 0){
						more_noisy(appid, exclude, function(newResults:MatchResults){
							remaining -= addEntry(results, newResults, exclude, remaining, meta, "noisy");
							if (remaining > 0){
								more_reverse(appid, exclude, function(newResults:MatchResults){
									remaining -= addEntry(results, newResults, exclude, remaining, meta, "reverse");
									finish();
								});
							}else {
								finish();
							}
						});
					}else{
						finish();
					}
				});
			}
			else
			{
				finish();
			}
		};
		
		var counter = picks.length;
		
		var mapArrs = new Map<String,MatchResults>();
		
		var onLoadPicks = function (callback){
			counter--; 
			if (counter == 0) processStuff(mapArrs);
		};
		
		for (i in 0...picks.length){
			
			var pick = picks[i];
			var count = counts[i];
			
			if (mapArrs.exists(pick) == false){
				mapArrs.set(pick, new MatchResults());
			}
			
			var mr:MatchResults = mapArrs.get(picks[i]);
			switch(picks[i]){
				case "noisy":     more_noisy(appid, exclude, function(a:MatchResults){ mr.concat(a); mapArrs.set(pick, mr); onLoadPicks(callback); });
				case "reverse": more_reverse(appid, exclude, function(a:MatchResults){ mr.concat(a); mapArrs.set(pick, mr); onLoadPicks(callback); });
				case "more":            more(appid, exclude, function(a:MatchResults){ mr.concat(a); mapArrs.set(pick, mr); onLoadPicks(callback); });
				case "gems":  more_from_tags_plus(appid, exclude,  true, 12, function(a:MatchResults){ mr.concat(a); mapArrs.set(pick, mr); onLoadPicks(callback); });
				case "tags":  more_from_tags_plus(appid, exclude, false, 12, function(a:MatchResults){ mr.concat(a); mapArrs.set(pick, mr); onLoadPicks(callback); });
				default: 
			}
		}
	}
	
	public static function tagsFor(appid:String, callback:Array<String>->Void)
	{
		tagDB.getTagsForApp(appid, callback);
		/*indexedLines("data/v2/tags/apps/", appid, function(arr:Array<String>){
			callback(arr);
		});*/
	}
	
	public static function more(appid:String, exclude:Array<String>, callback:MatchResults->Void)
	{
		indexedLines("data/v2/more/", appid, function(arr:Array<String>){
			filter(arr, exclude, function(arr:Array<String>){
				callback(new MatchResults(arr));
			});
		});
	}
	
	public static function more_noisy(appid:String, exclude:Array<String>, callback:MatchResults->Void)
	{
		indexedLines("data/v2/more_noisy/", appid, function(arr:Array<String>){
			filter(arr, exclude, function(arr:Array<String>){
				filterLowRated(arr, function(arr:Array<String>){
					sortByTags(appid, arr, callback);
				});
			});
		});
	}
	
	public static function more_reverse(appid:String, exclude:Array<String>, callback:MatchResults->Void)
	{
		indexedLines("data/v2/more_reverse/", appid, function(arr:Array<String>){
			filter(arr, exclude, function(arr:Array<String>){
				filterLowRated(arr, function(arr:Array<String>){
					sortByTags(appid, arr, callback);
				});
			});
		});
	}
	
	public static function rating(appid:String, gem:Bool, callback:Float->Void)
	{
		var file = (gem ? "gem" : "top") + ".tsv";
		fileLines("data/v2/reviews/", file, appid, function(arr:Array<String>){
			var rating = 0.5;
			if (arr != null && arr.length > 0) {
				rating = Std.parseFloat(arr[0]);
				if (rating == null || Math.isNaN(rating)) {
					rating = 0.5;
				}
			}
			callback(rating);
		});
	}
	
	private static function sortByTags(appid:String, arr:Array<String>, callback:MatchResults->Void){
		var candidates = [];
		var count = arr.length;
		var timer = Timer.stamp();
		if (count == 0) {
			callback(new MatchResults(arr));
			return;
		}
		tagsFor(appid, function(parentTags:Array<String>){
			tagProfile(parentTags, function(parentProfile:Map<String,Array<String>>){
				for (otherApp in arr){
					tagsFor(otherApp, function(otherTags:Array<String>){
						tagProfile(otherTags, function(otherProfile:Map<String,Array<String>>){
							var score = compareCandidates(appid, otherApp, parentProfile, otherProfile);
							candidates.push({appid:otherApp, score:score});
							count--;
							if (count <= 0){
								candidates.sort(function (a:{appid:String, score:Float}, b:{appid:String, score:Float}):Int{
									if (a.score < b.score) return  1;
									if (a.score > b.score) return -1;
									return 0;
								});
								var results = new MatchResults();
								for (cand in candidates){
									results.add(cand.appid, cand.score);
								}
								callback(results);
							}
						});
					});
				}
			});
		});
	}
	
	private static function filterLowRated(arr:Array<String>, callback:Array<String>->Void)
	{
		topRating("10", function(f:Float){
			var final = [];
			for (appid in arr){
				var score:Float = topScores.get(appid);
				if (score >= 0.8){
					final.push(appid);
				}
			}
			callback(final);
		});
	}
	
	private static function filter(arr:Array<String>, exclude:Array<String>, callback:Array<String>->Void)
	{
		var arr2 = [];
		for (thing in arr){
			if (exclude.indexOf(thing) == -1){
				arr2.push(thing);
			}
		}
		callback(arr2);
	}
	
	/*
	public static function gb_similar(appid:String, exclude:Array<String>, callback:Array<String>->Void)
	{
		fileLines("data/v2/", "gb_similar.tsv", appid, function(arr:Array<String>){
			filter(arr, exclude, callback);
		});
	}
	*/
	
	public static function metaName(meta:String):String
	{
		return switch(meta){
			//case "gb": "Similar (Giant Bomb)";
			case "more": "Default match";
			case "reverse": "Reverse match";
			case "noisy": "Loose match";
			case "tags": "Similar tags";
			case "gems": "Hidden Gem";
			case "tags_dumb": "Tags (Naive)";
			case "gems": "Tags (Naive)";
			case "selected": "Selected";
			default: "";
		}
	}
	
	public static function metaText(appid:String, mainAppid:String, meta:String, callback:String->Void)
	{
		name(appid, function(localName:String){
			name(mainAppid, function(mainName:String){
				
				var process = function(payload:String){
					var result = 
					switch(meta){
						case "gb":     '$localName is a "similar games" match for $mainName\n\n(according to GiantBomb\'s database)';
						case "more":   '$localName is a "more like this" match for $mainName\'\n\n($mainName recommends $localName)';
						case "reverse":'$localName is a reverse "more like this" match for $mainName\n\n($localName recommends $mainName)';
						case "noisy":  '$localName is a loose "more like this" match for $mainName\n\n($localName is recommended by a game recommended by $mainName)';
						case "tags":   '$localName has several tags in common with $mainName\n\n'+payload;
						case "gems":   '$localName is a highly rated but little known game with several tags in common with $mainName\n\n'+payload;
						case "tags_dumb":   '$localName is has several tags in common with $mainName, but we assessed this in a dumb and naive way';
						case "gems_dumb":   '$localName is a highly rated but little known game with several tags in common with $mainName, but we assessed this in a dumb and naive way';
						
						default: "???";
					}
					callback(result);
				}
				
				if (meta == "tags" || meta == "gems"){
					getTagComparison(appid, mainAppid, process);
				}else{
					process("");
				}
				
			});
		});
	}
	
	public static function name(appid:String, callback:String->Void)
	{
		if (id2title.exists(appid) != false){
			var name = id2title.get(appid);
			if (name == null || name == ""){
				name = "<" + appid + ">";
			}
			callback(name);
			return;
		}
		Get.titles(
			function (appids:Array<String>, names:Array<String>)
			{
				for (i in 0...appids.length)
				{
					id2title.set(appids[i], names[i]);
				}
				var name = id2title.get(appid);
				if (name == null || name == "")
				{
					callback("<" + appid + ">");
				}
				callback(name);
			}
		);
	}
	
	public static function text(text:String, size:Int=12, color:Int=0, bold:Bool=false, align:TextFormatAlign=LEFT):TextField
	{
		var t = new TextField();
		var dtf = t.defaultTextFormat;
		dtf.size = size;
		dtf.color = color;
		dtf.font = "helvetica";
		dtf.bold = bold;
		dtf.align = align;
		t.setTextFormat(dtf);
		t.text = text;
		t.width = 200;
		t.selectable = false;
		return t;
	}
	
	private static function loadGems(callback:Void->Void){
		file("data/v2/reviews/gem.tsv", function(data:String){
			var lines = data.split("\n");
			topAppsByGem = [];
			gemScores = new Map<String,Float>();
			var i = 0;
			for (line in lines){
				var cell = line.split("\t");
				var appid = cell[0];
				var score = cell[1];
				var scoreF = Std.parseFloat(score);
				if (scoreF == null || Math.isNaN(scoreF)){
					scoreF = 0.5;
				}
				gemScores.set(appid, scoreF);
				if(i < TOP_COUNT){
					topAppsByGem.push(appid);
				}
				i++;
			}
			callback();
		});
	}
	
	private static function loadTops(callback:Void->Void){
		file("data/v2/reviews/top.tsv", function(data:String){
			var lines = data.split("\n");
			topAppsByTop = [];
			topScores = new Map<String,Float>();
			var i = 0;
			for (line in lines){
				var cell = line.split("\t");
				var appid = cell[0];
				var score = cell[1];
				var scoreF = Std.parseFloat(score);
				if (scoreF == null || Math.isNaN(scoreF)){
					scoreF = 0.5;
				}
				topScores.set(appid, scoreF);
				if(i < TOP_COUNT){
					topAppsByTop.push(appid);
				}
				i++;
			}
			callback();
		});
	}
	
	private static function loadReviews(callback:Void->Void){
		file("data/v2/reviews/raw.tsv", function(data:String){
			var lines = data.split("\n");
			reviewScores = new Map<String,{ratings:Int,posRatings:Int}>();
			for (line in lines){
				var cell = line.split("\t");
				var appid = cell[0];
				var posRatings = Std.parseInt(cell[1]);
				var ratings = Std.parseInt(cell[2]);
				if (posRatings == null) posRatings = 0;
				if (ratings== null) ratings = 0;
				reviewScores.set(appid, {ratings:ratings,posRatings:posRatings});
			}
			callback();
		});
	}
	
	public static function gemRating(appid:String, callback:Float->Void){
		
		if (gemScores == null){
			loadGems(function(){
				callback(gemScores.get(appid));
			});
		}else{
			callback(gemScores.get(appid));
		}
	}
	
	public static function topRating(appid:String, callback:Float->Void){
		if (topScores == null){
			loadTops(function(){
				callback(topScores.get(appid));
			});
		}else{
			callback(topScores.get(appid));
		}
	}
	
	public static function naiveRating(appid:String, callback:Float->Void){
		reviews(appid, function(data:{ratings:Int, posRatings:Int}){
			if (data == null || data.ratings == 0){
				callback(0.5);
				return;
			}
			callback(data.posRatings / data.ratings);
		});
	}
	
	public static function reviews(appid:String, callback:{ratings:Int, posRatings:Int}->Void){
		if (reviewScores == null){
			loadReviews(function(){
				var data = reviewScores.get(appid);
				if (data == null){
					data = {ratings:0, posRatings:0};
				}
				callback(data);
			});
		}else{
			var data = reviewScores.get(appid);
			if (data == null){
				data = {ratings:0, posRatings:0};
			}
			callback(data);
		}
	}
	
	public static function getTagComparison(parent:String, candidate:String, callback:String->Void){
		var meta = [];
		tagsFor(parent, function(parentTags:Array<String>){
			tagsFor(candidate, function(candidateTags:Array<String>){
				assessCandidate(parent, candidate, parentTags, candidateTags, function(score:Float){
					callback(meta.join("\n"));
				}, meta);
			});
		});
	}
	
	public static function compareGamesTags(parent:String, candidate:String, isGems:Bool, callback:Float->Void, meta:Array<String>=null)
	{
		tagsFor(parent, function(parentTags:Array<String>){
			tagsFor(candidate, function(candidateTags:Array<String>){
				assessCandidate(parent, candidate, parentTags, candidateTags, function(score:Float){
					{
						callback(score);
					}
				}, meta);
			});
		});
	}
	
	private static function tagProfile(tags:Array<String>,callback:Map<String,Array<String>>->Void)
	{
		tagDB.getTagProfile(tags, function(map:Map<String,Array<String>>){
			callback(map);
		});
	}
	
	private static function assessCandidate(parent:String, candidate:String, parentTags:Array<String>, candidateTags:Array<String>, callback:Float->Void, meta:Array<String>=null)
	{
		tagProfile(parentTags, function(parentProfile:Map<String,Array<String>>){
			tagProfile(candidateTags, function(candidateProfile:Map<String,Array<String>>){
				var matchScore:Float = compareCandidates(parent, candidate, parentProfile, candidateProfile, meta);
				callback(matchScore);
			});
		});
	}
	
	public static function compareCandidates(parentId:String, candidateId:String, parent:Map<String,Array<String>>, candidate:Map<String,Array<String>>, meta:Array<String>=null):Float
	{
		var categoryScores:Map<String,Float> = new Map<String,Float>();
		
		var totalScore:Float = 0.0;
		
		var allCategories = [];
		for (category in parent.keys()){
			if(allCategories.indexOf(category) == -1) allCategories.push(category);
		}
		for (category in candidate.keys()){
			if(allCategories.indexOf(category) == -1) allCategories.push(category);
		}
		
		for (category in allCategories)
		{
			var metaStr = "";
			var matchedTags = null;
			var penaltyTags = null;
			
			var categoryScore = 0.0;
			categoryScores.set(category, 0.0);
			
			var parentTags = parent.get(category);
			var candidateTags = candidate.get(category);
			
			if (parentTags == null) parentTags = [];
			if (candidateTags == null) candidateTags = [];
			
			var candidateTagsNotOnParent = 0;
			var parentTagsNotOnCandidate = 0;
			
			for (tag in parentTags){
				var i = candidateTags.indexOf(tag);
				if (i != -1){
					categoryScore += 1.0;
				}else{
					parentTagsNotOnCandidate++;
					if (penaltyTags == null) penaltyTags = [];
					penaltyTags.push(parentTagsNotOnCandidate);
				}
				if (meta != null){
					if (matchedTags == null) matchedTags = [];
					if(i != -1) matchedTags.push(tagDB.unfixTag(tag));
				}
			}
			
			for (tag in candidateTags){
				var i = parentTags.indexOf(tag);
				if (i == -1){
					candidateTagsNotOnParent++;
				}
			}
			
			var categoryPenalty = 0.0;
			
			/*
			categoryPenalty = switch(category){
				case "warning": parentTagsNotOnCandidate * 1;
				default: 0.0;
			}
			*/
			
			var categoryWeight = getCategoryWeight(category);
			
			categoryScore -= categoryPenalty;
			categoryScore *= categoryWeight;
			categoryScores.set(category, categoryScore);
			
			totalScore += categoryScore;
			
			if (meta != null){
				if (categoryScore != 0){
					category = categoryName(category);
					var matched = (matchedTags != null ? (": " + matchedTags.join(",")) : "");
					if (categoryPenalty != 0){
						matched += penaltyTags.join(",");
					}
					metaStr += category + matched;
					if(metaStr != "" && metaStr != null){
						meta.push(metaStr);
					}
				}
			}
			
			if (parentId == "461640"){
				trace("category = " + category + " score = " + categoryScore + " penalty = " + categoryPenalty);
			}

		}
		
		
		if (meta != null){
			var i = 0;
			
			var totalPossible = compareCandidates(candidateId, candidateId, candidate, candidate);
			
			for (category in categoryScores.keys())
			{
				var categoryWeight = getCategoryWeight(category);
				var parentTags = parent.get(category);
				
				var score = categoryScores.get(category);
				
				
				if (score != 0){
					var p = score/totalScore;
					var perc = Std.string(Std.int(100 * p)) + "%";
					meta[i] = (score < 0 ? "" : "+") + score + " for " + meta[i];
					i++;
				}
			}
			meta.sort(function(a:String, b:String):Int{
				var abit = a.split(" ");
				var bbit = b.split(" ");
				if (abit != null && abit.length > 0) a = abit[0];
				if (bbit != null && bbit.length > 0) b = bbit[0];
				if(a.indexOf("+") == 0) a = a.substr(1, a.length - 1);
				if(b.indexOf("+") == 0) b = b.substr(1, b.length - 1);
				var ai = Std.parseInt(a);
				var bi = Std.parseInt(b);
				if (ai == null && bi != null) return 1;
				if (ai != null && bi == null) return -1;
				if (ai == null && bi == null) return 0;
				if (ai < bi) return 1;
				if (ai > bi) return -1;
				return 0;
			});
			var perc = Std.int(100 * totalScore / totalPossible) + "%";
			meta.push("----------------------------------------------");
			meta.push(perc + ": " + totalScore + " out of possible " + totalPossible);
		}
		
		return totalScore;
	}
	
	private static function categoryName(str:String):String{
		if (str == "weak") return "Other";
		return fu(str);
	}
	
	private static function getCategoryWeight(str:String):Float{
		return switch(str){
			case "subgenre":   4.0;
			case "viewpoint":  3.0;
			case "theme":      2.0;
			case "players":    2.0;
			case "feature":    2.0;
			case "time":       2.0;
			case "story":      2.0;
			case "genre":      2.0;
			case "character":  1.0;
			case "challenge":  1.0;
			case "adjective":  1.0;
			case "noun":       1.0;
			case "warning":    1.0;
			case "weak":       0.5;
			case "misc":       1.0;
			case "playtime":   1.0;
			default: 1.0;
		}
	}
	
	private static function fu(str:String):String{
		return str.substr(0, 1).toUpperCase() + str.substr(1, str.length - 1);
	}
	
	public static function more_from_tags_plus(appid:String, exclude:Array<String>, isGems:Bool, count:Int, callback:MatchResults->Void)
	{
		var onResults = function(mr:MatchResults){
			
			var arr2:Array<{appid:String,score:Float}> = [];
			var counter = mr.appids.length;
			if (mr.appids.length == 0){
				callback(new MatchResults());
				return;
			}
			for (i in 0...mr.appids.length){
				var otherappid = mr.appids[i];
				compareGamesTags(appid, otherappid, isGems, function(f:Float){
					
					var finalize = function(f:Float){
						if(appid != otherappid){
							arr2.push({appid:otherappid, score:f});
						}
						counter--;
						if (counter <= 0){
							arr2.sort(function(a:{appid:String,score:Float}, b:{appid:String, score:Float}):Int{
								if (a.score > b.score) return -1;
								if (a.score < b.score) return  1;
								return 0;
							});
							var results = new MatchResults();
							var i = 0;
							while (count > 0 && i < arr2.length){
								var theAppid = arr2[i].appid;
								if (theAppid != appid && results.appids.indexOf(theAppid) == -1){
									results.add(arr2[i].appid, arr2[i].score);
								}
								i++;
							}
							callback(results);
						}
					};
					
					if (isGems){
						gemRating(appid, function(gemScore:Float){
							/*var weight = 0.25;
							f = f * (1 - weight);
							f = f + (gemScore * weight);*/
							finalize(f);
						});
					}else{
						finalize(f);
					}
				});
			}
		};
		
		if(isGems){
			more_from_gems(appid, exclude, onResults);
		}else{
			more_from_tags(appid, exclude, onResults);
		}
	}
	
	public static function more_from_gems(appid:String, exclude:Array<String>, callback:MatchResults->Void)
	{
		if (topAppsByGem == null){
			loadGems(function(){
				filter(topAppsByGem, exclude, function(results:Array<String>){
					callback(new MatchResults(results));
				});
			});
		}else{
			filter(topAppsByGem, exclude, function(results:Array<String>){
				callback(new MatchResults(results));
			});
		}
	}
	
	public static function more_from_tops(appid:String, exclude:Array<String>, callback:MatchResults->Void)
	{
		if (topAppsByTop == null){
			loadTops(function(){
				filter(topAppsByTop, exclude, function(results:Array<String>){
					callback(new MatchResults(results));
				});
			});
		}else{
			filter(topAppsByTop, exclude, function(results:Array<String>){
				callback(new MatchResults(results));
			});
		}
	}
	
	public static function more_from_tags(appid:String, exclude:Array<String>, callback:MatchResults->Void)
	{
		tagsFor(appid, function(tags:Array<String>){
			tagProfile(tags, function(profile:Map<String,Array<String>>){
				
				var check = function(tags:Array<String>):Array<String>{
					var finals = [];
					if (tags == null || tags.length == 0) return finals;
					for (tag in tags){
						if (tag == null || tag == "") continue;
						if (false == (tagDB.isWeakQuick(tag))){
							finals.push(tag);
						}
					}
					return finals;
				}
				
				var genres =    check(profile.get("genre"));
				var theme     = check(profile.get("theme"));
				var viewpoint = check(profile.get("viewpoint"));
				var rpg       = check(profile.get("rpg"));
				
				var culledTags = [];
				if (theme.length  > 0)    culledTags.push(theme[0]);
				if (genres.length > 0)    culledTags.push(genres[0]);
				if (viewpoint.length > 0) culledTags.push(viewpoint[0]);
				if (rpg.length > 0)       culledTags.push(rpg[0]);
				
				
				if (culledTags.length > 0){
					tagDB.getAppsWithTags(culledTags, function(results:Array<String>){
						filter(results, exclude, function(results:Array<String>){
							filterLowRated(results, function(results:Array<String>){
								callback(new MatchResults(results));
							});
						});
					});
				}else{
					callback(new MatchResults([]));
				}
			});
		});
	}
	
	/*
	public static function more_from_tags_naive(appid:String, exclude:Array<String>, isGems:Bool, count:Int, callback:MatchResults->Void)
	{
		trace("more_from_tags_naive(" + appid + ")");
		var map:Map<String,{score:Float,matches:Int,notes:String}> = new Map<String,{score:Float,matches:Int,notes:String}>();
		tagsFor(appid, function(tags:Array<String>){
			
			trace("tagsFor(" + appid + ") = " + tags);
			
			var count = tags.length;
			if (count == 0){
				callback(new MatchResults());
				return;
			}
			trace("!!!tags = " + tags);
			for (tag in tags){
				tagDB.getEntries(tag, count, isGems, function(arr:Array<TagEntry>){
					
					for (tagEntry in arr){
						var candidate = null;
						if (exclude.indexOf(tagEntry.appid) != -1){
							candidate = null;
						}else{
							candidate = map.get(tagEntry.appid);
						}
						if (candidate == null){
							candidate = {score:tagEntry.score, matches:1, notes:tagEntry.score+",tags="+tag};
							map.set(tagEntry.appid, candidate);
						}else{
							candidate.matches++;
							candidate.notes += "," + tag;
						}
					}
					
					count--;
					
					trace("tag(" + tag + ") count = " + count);
					
					if (count <= 0){
						var list = [];
						var results = new MatchResults();
						for (key in map.keys()){
							var entry = map.get(key);
							list.push({id:key, combined:entry.score*entry.matches, notes:entry.notes});
						}
						list.sort(function (a:{id:String, combined:Float, notes:String}, b:{id:String, combined:Float, notes:String}):Int{
							if (a.combined > b.combined) return -1;
							if (a.combined < b.combined) return  1;
							return 0;
						});
						for (thing in list){
							results.add(thing.id, thing.combined);
						}
						
						
						for (thing in list){
							var name = id2title.get(thing.id);
						}
						
						callback(results);
					}
				});
			}
		});
	}
	*/
	
	public static function fileLines(path:String, file:String, appid:String, callback:Array<String>->Void)
	{
		LinesIndex.lines(path, file, appid, callback);
	}
	
	public static function indexedLines(path:String, appid:String, callback:Array<String>->Void)
	{
		LinesIndex.indexedLines(path, appid, callback);
	}
	
	
}