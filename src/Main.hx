package;

import haxe.Http;
import haxe.Timer;
import js.Browser;
import js.html.DOMElement;
import js.html.DivElement;
import js.html.Document;
import js.html.Text;
import js.html.Window;
import openfl.geom.Point;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.Lib;
import openfl.display.Stage;
import openfl.display.StageScaleMode;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.geom.ColorTransform;
import openfl.text.TextField;
import openfl.text.TextFormatAlign;

/**
 * ...
 * ...
 * @author 
 */
class Main extends Sprite 
{
	static inline var WIDTH:Int = 950;
	static inline var HEIGHT:Int = 600;
	static inline var RINGSIZE:Float = 350;
	static inline var CRUMBSIZE:Float = 100;
	
	public var lastappid:String;
	public var mainContainer:Sprite;
	public var mainImage:DisplayObject;
	public var daughterImages:Array<Sprite>=[];
	public var daughterApps:MatchResults = new MatchResults();
	
	public var breadcrumbs:Array<Breadcrumb> = [];
	public var breadcrumbsSprite:Sprite;
	
	public var gameappids:Array<String> = [];
	
	public var currApp:String;
	public var shownApp:String;
	
	private var box:Sprite;
	private var bkg:Bitmap;
	private var dummySquare:Bitmap;
	
	private var textTitle:DOMElement;
	private var textBody:DOMElement;
	
	private var screenshotContainer:Sprite;
	
	private var canvas:Sprite;
	
	private var back:Sprite;
	private var more:Sprite;
	
	private var btnGems:Sprite;
	private var btnTags:Sprite;
	private var btnLoose:Sprite;
	private var btnReverse:Sprite;
	
	public static var recGems:Bool = true;
	public static var recTags:Bool = true;
	public static var recReverse:Bool = true;
	public static var recLoose:Bool = true;
	
	private var waiting:Bool = false;
	private var tooltip:Tooltip;
	
	private var seenApps:Array<String> = [];
	
	public static var MAIN_APP = "";
	public static var RECOMMENDERS:Array<{id:String,count:Int}> = [];
	
	public function new()
	{
		trace("Version 1.0.3");
		
		MAIN_APP = "";
		
		if (MAIN_APP == ""){
			var apps = [
				"692850", //Bloodstained
				"218410", //Defender's Quest
				"211420", //Dark Souls
				"8930",   //Civilization V
				"250760", //Shovel Knight
				"674930", //Boyfriend Dunegon
				"751780", //Forager
				"39140",  //Final Fantasy VII
				"570",    //Dota 2
				"730",    //CS:GO
				"400",    //Portal
			];
			var i:Int = Std.int(Math.random() * apps.length);
			MAIN_APP = apps[i];
		}
		
		/*
		//TODO:
		
		- Provide full set of app details
		- Process shorthand metadata files
		   - appid
		   - name
		   - header
		   - tags
		   - genre
		   
		- Create "insertion points" for finding stuff
		   - Show me some games with X/Y/Z tags / categories
		   - Show me some games by the same developer/publisher
		   - Show me some games from the GB similarity
		   - Show me some games from the hidden gem detector
		   - Show me some games from X/Y/Z curator(s)
		   
		 - Enable a "shortlist" of like 3-5 games
		 
		 -  
		
		- Toggle graph mode
		  - Steam recommendations
		
		- Process GB DB and set up relationship graphs
		
		*/
		
		super();
		
		Get.tagsFor("10", function(tags:Array<String>){
			init();
		});
	}
	
	private function init()
	{
		getVariables();
		
		canvas = new Sprite();
		
		var button = getImageButton(MAIN_APP, "selected", 0.0, onClickMain, onOverMore, onOutMore);
		canvas.addChild(button);
		
		addChild(canvas);
		
		var canvasRatio:Float = 1.0;
		
		Lib.current.stage.addEventListener(Event.RESIZE, function(e:Event){
			var stage:Stage = cast e.target;
			var min = Math.min(stage.stageWidth, stage.stageHeight);
			onResize(stage.stageWidth, stage.stageHeight);
		});
		
		bkg = getSquare(WIDTH, HEIGHT, 0x1B2838);
		add(bkg);
		
		Get.titles(function(appids:Array<String>, names:Array<String>){
			gameappids = appids;
			setEntry(MAIN_APP);
		});
		
		back = getButton("Back", onClickBack);
		add(back);
		back.width *= 0.25;
		back.height *= 0.25;
		back.x = 4;
		back.y = HEIGHT - back.height - 4;
		
		more = getButton("More", onClickMore.bind(""));
		add(more);
		more.width *= 0.25;
		more.height *= 0.25;
		more.x = (WIDTH - more.width) - 4;
		more.y = back.y;
		
		btnGems = getButton2("Gems", onClickRec.bind("gems"));
		btnTags = getButton2("Tags", onClickRec.bind("tags"));
		btnLoose = getButton2("Loose", onClickRec.bind("loose"));
		btnReverse = getButton2("Reverse", onClickRec.bind("reverse"));
		//btnDefault = getButton2("Default", onClickRec.bind("default"));
		
		btnGems.width *= 0.20;
		btnTags.width *= 0.20;
		btnLoose.width *= 0.20;
		btnReverse.width *= 0.20;
		//btnDefault.width *= 0.20;
		
		btnGems.height *= 0.20;
		btnTags.height *= 0.20;
		btnLoose.height *= 0.20;
		btnReverse.height *= 0.20;
		//btnDefault.height *= 0.20;
		
		add(btnGems);
		add(btnTags);
		add(btnLoose);
		add(btnReverse);
		//add(btnDefault);
		
		arrangeBtn2s();
		
		mainContainer = new Sprite();
		add(mainContainer);
		
		resizeTimer = new Timer(100);
		resizeTimer.run = function(){
			onResize(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
			resizeTimer.stop();
			resizeTimer = new Timer(1000);
			resizeTimer.run = function(){
				onResize(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
				resizeTimer.stop();
				resizeTimer = new Timer(5000);
				resizeTimer.run = function(){
					onResize(Lib.current.stage.stageWidth, Lib.current.stage.stageHeight);
					resizeTimer.stop();
				}
			}
		}
		
		textTitle = cast Browser.document.getElementById("game_title");
		textBody = cast Browser.document.getElementById("game_description");
		
		tooltip = getTooltip();
		
		box = getBox(WIDTH, HEIGHT, 4, 0xFFFFFF);
		add(box);
		
		onClickRec("");
	} 
	private var resizeTimer:Timer = null;
	
	private function arrangeBtn2s(){
		
		var startX = back.x + back.width + 10;
		var endX = more.x - 10;
		var space = (endX - startX) - (btnGems.width * 4);
		var gaps = 3;
		var gapSpace = (space) / gaps;
		
		var btns = [btnGems, btnTags, btnLoose, btnReverse];// , btnDefault];
		var lastX = startX;
		var lastY = more.y + (more.height - btnGems.height) / 2;
		
		if (gapSpace < 0){
			startX = back.x + 10;
			endX = more.x + more.width - 10;
			space = (endX - startX) - (btnGems.width * 4);
			gaps = 3;
			gapSpace = space / gaps;
			lastY = more.y - btnGems.height - 5;
			lastX = startX;
		}
		
		for (i in 0...4){
			var btn = btns[i];
			btn.x = lastX;
			btn.y = lastY;
			lastX += btn.width + gapSpace;
		}
		
		var values = [false, false, false, false];
		for (rec in RECOMMENDERS){
			switch(rec.id){
				case "gems":          values[0] = true;
				case "tags":          values[1] = true;
				case "loose","noisy": values[2] = true;
				case "reverse":       values[3] = true;
				default: //donothing
			}
		}
		
		for (i in 0...btns.length){
			var btn = btns[i];
			var value = values[i];
			if (!value){
				btn.transform.colorTransform = new ColorTransform(0.5, 0.5, 0.5);
			}else{
				btn.transform.colorTransform = new ColorTransform(1.0, 1.0, 1.0);
			}
		}
	}
	
	private function getVariables()
	{
		var href = Browser.window.location.href;
		var arr = href.split("?");
		if (arr != null && arr.length >= 2){
			var varStr = arr[1];
			var vars = varStr.split("&");
			for (variable in vars){
				var nameValue = variable.split("=");
				if (nameValue != null && nameValue.length >= 2){
					var name = nameValue[0];
					var value = nameValue[1];
					switch(name){
						case "appid": MAIN_APP = value;
						case "recommenders": setRecommenders(value.split(","));
					}
				}
			}
		}
		
		trace("MAIN_APP = " + MAIN_APP);
		trace("RECOMMENDERS = " + RECOMMENDERS);
	}
	
	private function setRecommenders(arr:Array<String>)
	{
		var count:Int = switch(arr.length){
			case 1: 8;
			case 2: 4;
			case 3: 3;
			case 4: 2;
			default: 12;
		}
		
		for (i in 0...arr.length){
			arr[i] = arr[i] + ":" + count;
		}
		
		if (arr.length == 0){
			arr = ["default:12"];
		}
		
		RECOMMENDERS = [];
		for (value in arr){
			var nameCount = value.split(":");
			var name = normalizeRecommender(nameCount[0]);
			var recommender:{id:String,count:Int} = {id:name, count:4};
			if (value.length > 1){
				var i = Std.parseInt(nameCount[1]);
				if (i != null){
					recommender.count = i;
				}
			}
			RECOMMENDERS.push(recommender);
		}
	}
	
	private function normalizeRecommender(name:String){
		return switch(name.toLowerCase()){
			case "more","match": "more";
			case "gb", "giantbomb": "gb";
			case "noisy", "loose": "noisy";
			case "reverse": "reverse";
			case "tags","tag": "tags";
			case "gems", "gem": "gems";
			case "tags_dumb": "tags_dumb";
			case "gems_dumb": "gems_dumb";
			default: "more";
		}
	}
	
	private var resizeCount:Int = 0;
	private var currWidth:Int=-1;
	private var currHeight:Int=-1;
	
	private function onResize(width:Int, height:Int)
	{
		if (width == currWidth && height == currHeight){
			if (resizeCount > 3){
				return;
			}else{
				resizeCount++;
			}
		}else{
			resizeCount = 0;
		}
		currWidth = width;
		currHeight = height;
		
		var newBkg = getSquare(WIDTH, HEIGHT, 0x1B2838);
		if (bkg != null){
			replace(bkg, newBkg);
		}else{
			add(newBkg);
		}
		bkg = newBkg;
		
		var xScale:Float = width / WIDTH;
		var yScale:Float = height / HEIGHT;
		var minScale:Float = Math.min(xScale, yScale) * 0.98;
		
		var theHeight = 550;
		var boxHeight = Std.int(theHeight * minScale + back.height)+2;
		
		if (boxHeight < 400){
			boxHeight = 400;
		}
		
		var newBox = getBox(width, boxHeight, 4, 0xFFFFFF);
		if (box != null) {
			replace(box, newBox);
		}else{
			add(newBox);
		}
		box = newBox;
		
		back.x = 0;
		more.x = (box.width - more.width);
		
		back.y = boxHeight - back.height;
		more.y = back.y;
		
		arrangeBtn2s();
		
		mainContainer.scaleX = minScale;
		mainContainer.scaleY = minScale;
		
		mainContainer.y = 5 + (120 * minScale);
		
		onTop(back);
		onTop(btnGems);
		onTop(btnTags);
		onTop(btnLoose);
		onTop(btnReverse);
		//onTop(btnDefault);
		onTop(more);
		
		
	}
	
	public function hideTooltip()
	{
		if (canvas.contains(tooltip.sprite))
		{
			canvas.removeChild(tooltip.sprite);
		}
	}
	
	public function showTooltip(onWhat:DisplayObject, title:String, body:String)
	{
		hideTooltip();
		
		tooltip.setText(title, body);
		
		tooltip.sprite.x = onWhat.x + onWhat.width;
		tooltip.sprite.y = onWhat.y + mainContainer.y;
		
		if (tooltip.sprite.x + tooltip.sprite.width > WIDTH){
			tooltip.sprite.x = onWhat.x - tooltip.sprite.width - 10;
		}
		
		canvas.addChild(tooltip.sprite);
	}
	
	public function onTop(obj){
		canvas.setChildIndex(obj, canvas.numChildren);
	}
	
	public function replace(oldObj, newObj){
		var i = canvas.getChildIndex(oldObj);
		
		if (i != -1){
			canvas.removeChild(oldObj);
			canvas.addChildAt(newObj, i);
		}
	}
	
	public function remove(obj){
		canvas.removeChild(obj);
	}
	
	public function add(obj){
		canvas.addChild(obj);
	}
	
	public function clearPanel(){
		//textTitle.textContent = "";
		//textBody.textContent = "";
		textTitle.innerHTML = "";
		textBody.innerHTML = "";
		/*
		screenshotContainer.removeChildren();
		*/
	}
	
	public function showPanel(appid:String){
		
		shownApp = appid;
		clearPanel();
		
		Get.details(appid, function(data:Dynamic){
			
			if (data == null)
			{
				textTitle.innerHTML = "Error appid=" + appid + "";
				textBody.innerHTML = "<br>Couldn't load app details";
				return;
			}
			
			textTitle.innerHTML = data.name;
			
			var genres = "";
			var genreArr:Array<Dynamic> = data.genres;
			for (genre in genreArr){
				var desc = genre.description;
				if (genres != "") genres += ", ";
				genres += desc;
			}
			
			var tags = "";
			var tagArr:Array<String> = data.tags;
			for (tag in tagArr){
				if (tags != "") tags += ", ";
				tags += Get.unfixTag(tag);
			}
			
			var categories = "";
			var categoriesArr:Array<Dynamic> = data.categories;
			for (category in categoriesArr){
				var desc = category.description;
				if (categories != "") categories += ", ";
				categories += desc;
			}
			
			var recommendations = data.recommendations != null ? data.recommendations.total : -1;
			
			var platformsArr = [];
			if (data.platforms.windows) platformsArr.push("Windows");
			if (data.platforms.mac) platformsArr.push("Mac");
			if (data.platforms.linux) platformsArr.push("Linux");
			
			var platforms = platformsArr.join(", ");
			var price = "???";
			
			try{
				price = data.price_overview.final_formatted;
			}catch(msg:Dynamic){
				price = "???";
			}
			
			if (price == "???"){
				if (data.is_free){
					price = "Free";
				}
			}
			
			var ratingPercent:String = data.ratingPercent;
			var ratings:Int = data.ratings;
			var posRatings:Int = data.posRatings;
			
			var htmlText = "";
			htmlText += '<p style="text-align:center"><a href="https://store.steampowered.com/app/$appid">Visit store page</a></p><br>';
			htmlText += data.short_description;
			htmlText += "<br><br>";
			htmlText += "<strong>Price:</strong>  " + price + "<br>";
			htmlText += "<strong>Tags:</strong>  " + tags + "<br>";
			htmlText += "<strong>Genres:</strong>  " + genres + "<br>";
			htmlText += "<strong>Platforms:</strong>  " + platforms + "<br>";
			htmlText += "<strong>Categories:</strong>  " + categories + "<br>";
			htmlText += "<br>";
			htmlText += "<strong>Rating:</strong>  " + ratingPercent + " ---- " + ratings + " ratings" + "<br>";
			htmlText += "<br>";
			//htmlText += "<strong>Recommendations:</strong>  " + (recommendations > 0 ? Std.string(recommendations) : "???") + "<br>";
			
			var screenshots:Array<Dynamic> = data.screenshots;
			var xx = 0;
			var yy = 0;
			
			var j = 0;
			
			htmlText += "<br>";
			htmlText += "<div>";
			
			var path_trailer:String = "";
			var thumbnail:String = "";
			
			if (data.movies != null)
			{
				var movies:Array<Dynamic> = data.movies;
				for (movie in movies){
					var name = movie.name;
					if (path_trailer == "" || name.toLowerCase().indexOf("launch") != -1){
						var webm = movie.webm;
						path_trailer = Reflect.field(webm, "480");
						thumbnail = movie.thumbnail;
					}
				}
			}
			
			var numScreenShots = 4;
			
			if(path_trailer != ""){
				var video = '<video autoplay muted controls height="200" poster="$thumbnail" id="trailer" src="$path_trailer"></video>';
				htmlText += video;
				numScreenShots--;
			}
			
			for (si in 0...numScreenShots){
				var screenshot = screenshots[si];
				var path_thumbnail:String = screenshot.path_thumbnail;
				var path_full:String = screenshot.path_full;
				
				htmlText += '<a href="$path_full"><img src="$path_thumbnail" height="200"/></a>';
			}
			htmlText += '</div>';
			
			textBody.innerHTML = htmlText;
			
		});
	}

	public function addMain(s:DisplayObject){
		if (mainImage != null){
			removeChild(mainImage);
		}
		mainContainer.addChild(s);
		mainImage = s;
	}
	
	public function addDaughter(s:Sprite, appid:String, meta:AppMeta){
		if (seenApps.indexOf(appid) == -1) {
			seenApps.push(appid);
		}
		daughterImages.push(s);
		daughterApps.add(appid, meta.score, meta.recommender);
		mainContainer.addChild(s);
	}
	
	public function clearMain()
	{
		mainContainer.removeChild(mainImage);
		mainImage = null;
		if (dummySquare == null){
			dummySquare = getSquare(WIDTH, HEIGHT, 0x1B2838);
		}
		addMain(dummySquare);
		hideTooltip();
	}
	
	public function clearDaughters()
	{
		for (d in daughterImages){
			mainContainer.removeChild(d);
		}
		daughterImages.splice(0, daughterImages.length);
		daughterApps.clear();
		hideTooltip();
	}
	
	public function showRandomEntry()
	{
		var i:Int = Std.int(Math.random() * gameappids.length);
		var appid = Std.string(gameappids[i]);
		setEntry(appid);
	}
	
	public function setEntry(appid:String, daughters:MatchResults=null)
	{
		if (waiting) return;
		waiting = true;
		var change = false;
		if (currApp != appid || mainImage == null){
			seenApps = [];
			change = true;
		}
		currApp = appid;
		showEntry(appid, daughters, change);
		var stage = Lib.current.stage;
		onResize(stage.stageWidth, stage.stageHeight);
	}
	
	public function showEntry(appid:String, daughters:MatchResults, change:Bool=true)
	{
		clearDaughters();
		var spr = mainImage;
		var OFFSET = 0;
		if (change)
		{
			clearMain();
			clearPanel();
			spr = getImageButton(appid, "selected", 0.0, onClickMain, onOverMore, onOutMore);
			spr.scaleX *= 0.65;
			spr.scaleY *= 0.65;
			addMain(spr);
			spr.x = (WIDTH - spr.width) / 2;
			spr.y = (HEIGHT - spr.height) / 2;
			OFFSET = Std.int(spr.height - 20);
			spr.y -= OFFSET;
			showPanel(appid);
		}
		else{
			OFFSET = Std.int(mainImage.height - 20);
		}
		
		var temps = [];
		
		for (j in 0...8){
			var spr = getImageButton("", "loading", 0, null, null, null);
			var loc = getGridLoc2(j);
			loc.x *= RINGSIZE * 1.75;
			loc.y *= RINGSIZE;
			mainContainer.addChild(spr);
			spr.width *= 0.65;
			spr.height *= 0.65;
			spr.x = loc.x + (WIDTH - spr.width) / 2;
			spr.y = loc.y + (HEIGHT - spr.height) / 2;
			spr.y -= OFFSET;
			temps.push(spr);
		}
		
		var placeDaughters = function(more:MatchResults){
			
			waiting = false;
			
			if (more == null) more = new MatchResults();
			var count:Int = more.appids.length;
			var i = 0;
			
			var max = Std.int(Math.min(more.appids.length, 8));
			
			for (j in 0...max){
				
				if (j >= more.appids.length) continue;
				
				var otherAppid = more.appids[j];
				var score = more.scores[j];
				var metaStr = more.metas[j];
				
				var loc = getGridLoc2(i);
				
				loc.x *= RINGSIZE*1.75;
				loc.y *= RINGSIZE;
				
				var spr = getImageButton(otherAppid, metaStr, score, onClickMore, onOverMore, onOutMore);
				
				var appMeta = {
					appid:appid,
					recommender:metaStr,
					score:score
				}
				
				mainContainer.removeChild(temps[j]);
				addDaughter(spr, otherAppid, appMeta);
				spr.width *= 0.65;
				spr.height *= 0.65;
				spr.x = loc.x + (WIDTH - spr.width) / 2;
				spr.y = loc.y + (HEIGHT - spr.height) / 2;
				spr.y -= OFFSET;
				
				i++;
			}
			temps = null;
		}
		
		if (daughters != null)
		{
			placeDaughters(daughters);
		}
		else{
			Get.more_mix(appid, seenApps, function(results:MatchResults){
				
				var baseLineScore = 1.0;
				
				Get.compareGamesTags(appid, appid, false, function(f:Float){
					baseLineScore = f;
					for (i in 0...results.appids.length){
						if (results.scores[i] > 0){
							results.scores[i] /= baseLineScore;
						}
					}
					placeDaughters(results);
				});
			});
		}
	}
	
	public function onClickMain(appid:String)
	{
	}
	
	public function onClickBack()
	{
		var lastApp = breadcrumbs.pop();
		if (lastApp != null){
			setEntry(lastApp.appid, lastApp.recommendations);
		}
	}
	
	public function onClickRandom()
	{
		clearPanel();
		breadcrumbs.push(new Breadcrumb(currApp, daughterApps.copy()));
		showRandomEntry();
	}
	
	public function onOutMore(appid:String)
	{
		if (tooltip == null || tooltip.sprite == null) return;
		if (mainContainer == null) return;
		if (mainContainer.contains(tooltip.sprite)){
			hideTooltip();
		}
	}
	
	public function onOverMore(appid:String)
	{
		if (waiting) return;
		clearPanel();
		showPanel(appid);
		var i = daughterApps.appids.indexOf(appid);
		if (i != -1){
			var meta = daughterApps.metas[i];
			var metaName = Get.metaName(meta);
			Get.metaText(appid, currApp, meta, function(metaText:String){
				showTooltip(daughterImages[i], metaName, metaText);
			});
		}
	}
	
	public function onClickRec(str:String){
		switch(str){
			case "gems": recGems = !recGems;
			case "tags": recTags = !recTags;
			case "reverse": recReverse = !recReverse;
			case "loose","noisy": recLoose = !recLoose;
			default: //donothing
		}
		
		var btns = [btnGems, btnTags, btnLoose, btnReverse];
		var values = [recGems, recTags, recLoose, recReverse];
		
		var recs = ["gems", "tags", "noisy", "reverse"];
		
		var finals = [];
		
		for (i in 0...btns.length){
			var btn = btns[i];
			var value = values[i];
			if (!value){
				btn.transform.colorTransform = new ColorTransform(0.5, 0.5, 0.5);
			}else{
				btn.transform.colorTransform = new ColorTransform(1.0, 1.0, 1.0);
				finals.push(recs[i]);
			}
		}
		
		setRecommenders(finals);
		if (str != ""){
			for (app in daughterApps.appids){
				seenApps.remove(app);
			}
			onClickMore();
		}
	}
	
	public function onClickMore(appid:String="")
	{
		if (waiting) return;
		if (currApp == appid) return;
		
		if (appid == ""){
			appid = currApp;
		}
		
		breadcrumbs.push(new Breadcrumb(currApp, daughterApps.copy()));
		
		setEntry(appid);
	}
	
	public function getButton2(text:String, onClick:Void->Void, labelSize:Int=70):Sprite
	{
		var spr = new Sprite();
		spr.mouseEnabled = true;
		spr.addEventListener(MouseEvent.CLICK, function(e:MouseEvent){
			onClick();
		});
		var bd = new BitmapData(1, 1, false, 0x66BBFF);
		var bmp = new Bitmap(bd);
		bmp.width = 340;
		bmp.height = 150;
		var t:TextField = new TextField();
		t.text = text;
		t.selectable = false;
		t.textColor = 0x000000;
		var dtf = t.defaultTextFormat.clone();
		dtf.size = labelSize;
		dtf.bold = true;
		dtf.font = "helvetica";
		dtf.align = TextFormatAlign.CENTER;
		t.setTextFormat(dtf);
		
		spr.addChild(bmp);
		spr.addChild(t);
		t.width = bmp.width - 10;
		t.wordWrap = true;
		
		var textHeight = t.textHeight;
		if (text.indexOf("\n") != -1){
			textHeight *= 2;
		}
		
		t.x = Std.int((bmp.width - t.width) / 2);
		t.y = Std.int((bmp.height - textHeight) / 2);
		return spr;
	}
	
	public function getButton(text:String, onClick:Void->Void, labelSize:Int=80):Sprite
	{
		var spr = new Sprite();
		spr.mouseEnabled = true;
		spr.addEventListener(MouseEvent.CLICK, function(e:MouseEvent){
			onClick();
		});
		var bd = new BitmapData(1, 1, false, 0xFFFFFF);
		var bmp = new Bitmap(bd);
		bmp.width = 430;
		bmp.height = 190;
		var t:TextField = new TextField();
		t.text = text;
		t.selectable = false;
		t.textColor = 0x000000;
		var dtf = t.defaultTextFormat.clone();
		dtf.size = labelSize;
		dtf.bold = true;
		dtf.font = "helvetica";
		dtf.align = TextFormatAlign.CENTER;
		t.setTextFormat(dtf);
		
		spr.addChild(bmp);
		spr.addChild(t);
		t.width = bmp.width - 10;
		t.wordWrap = true;
		
		var textHeight = t.textHeight;
		if (text.indexOf("\n") != -1){
			textHeight *= 2;
		}
		
		t.x = Std.int((bmp.width - t.width) / 2);
		t.y = Std.int((bmp.height - textHeight) / 2);
		return spr;
	}
	
	private var mouseOverTimer:Timer = new Timer(250);
	private var mouseOnStage:Bool = false;
	private var mouseIsOver:String = "";
	private var mouseTicks:Int = 0;
	private var mouseOverTimerTicks:Int = 0;
	
	public function getImageButton(appid:String, meta:String, score:Float, onClick:String->Void, onOver:String->Void=null, onOut:String->Void=null):Sprite
	{
		var spr = new Sprite();
		
		if(appid != ""){
			spr.mouseEnabled = true;
			spr.addEventListener(MouseEvent.CLICK, function(e:MouseEvent){
				mouseIsOver = appid;
				if(onClick != null) onClick(appid);
			});
			
			var theAppid = appid;
			var mouseOverDelay = function(){
				if (mouseOverTimerTicks > 3){
					mouseOverTimer.stop();
				}
				if (mouseIsOver == theAppid){
					if (mouseTicks > 2){
						if (onOver != null) onOver(theAppid);
						mouseOverTimer.stop();
						mouseOverTimerTicks = 0;
					}else{
						mouseOverTimerTicks++;
					}
				}
			}
			
			spr.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent){
				hideTooltip();
				mouseIsOver = appid;
				mouseOverTimer.stop();
				mouseOverTimer = new Timer(500);
				var theAppid = appid;
				mouseOverTimer.run = mouseOverDelay;
			});
			
			spr.addEventListener(MouseEvent.MOUSE_MOVE, function(e:MouseEvent){
				if (mouseIsOver == appid){
					mouseTicks++;
				}else{
					mouseTicks = 0;
				}
				mouseIsOver = appid;
			});
			
			spr.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent){
				hideTooltip();
				mouseIsOver = "";
				mouseTicks = 0;
				if(onOut != null) onOut(appid);
			});
		}
		
		var textColor = 0xFFFFFF;
		var borderColor = switch(meta)
		{
			case "more": 0x850000;
			case "reverse": 0x850083;
			case "noisy": 0xa34a2b;
			case "gb": 0x786e56;
			case "tags": 0x00702d;
			case "gems": 0x0090ff;
			case "loading": 0x223344;
			default: 0xFFFFFF;
		}
		if (borderColor == 0xFFFFFF)
		{
			textColor = 0;
		}
		
		var bd = new BitmapData(1, 1, false, borderColor);
		var bmp = new Bitmap(bd);
		
		//460x215
		
		bmp.width = 440+10;
		bmp.height = 205+60;
		bmp.smoothing = true;
		
		var t:TextField = Get.text("", 30, 0xB0B0B0, true, TextFormatAlign.CENTER);
		if(appid != ""){
			Get.name(appid, function(name:String){
				if(t != null){
					t.text = name + "\n" +appid;
				}
			});
		}else{
			t.text = "Loading...";
		}
		
		spr.addChild(bmp);
		spr.addChild(t);
		t.width = bmp.width-10;
		t.x = Std.int((bmp.width - t.width) / 2);
		t.y = Std.int((bmp.height - (2*t.defaultTextFormat.size+4)) / 2);
		
		var oWidth = bmp.width;
		var oHeight = bmp.height;
		
		if(appid != ""){
			Get.image(Std.string(appid), function(b:BitmapData){
				if (b != null) {
					spr.removeChild(t);
					var bmp = new Bitmap(b);
					bmp.smoothing = true;
					spr.addChild(bmp);
					bmp.width = 440;
					bmp.height = 205;
					bmp.x = 5;
					bmp.y = 55;
				}
				var t2:TextField = Get.text("", 30, textColor, true, TextFormatAlign.LEFT);
				
				t2.text = Get.metaName(meta);
				t2.x = 5;
				t2.y = 5;
				t2.width = bmp.width-10;
				
				spr.addChild(t2);
				
				var perc = "";
				if (score > 0 && (meta == "tags" || meta == "gems")){
					perc = Std.int(score * 100) + "%";
					var t3:TextField = Get.text("", 30, textColor, true, TextFormatAlign.RIGHT);
					t3.text = perc;
					t3.width = bmp.width-10;
					t3.x = 5;
					t3.y = 5;
					spr.addChild(t3);
				}
			});
		}
		return spr;
	}
	
	function roundToNearest5(f:Float):Int
	{
		return Std.int((f / 5) + 0.5) * 5;
	}
	
	public function makeBreadcrumbs(appids:Array<Int>):Sprite
	{
		var bcrumbs = new Sprite();
		var crumbs:Array<Sprite> = [];
		var xx = 0.0;
		var count = 0;
		var target = appids.length;
		for (i in 0...appids.length)
		{
			var spr:Sprite = getImageButton(Std.string(appids[i]), "", 0.0, onClickBreadcrumb);
			spr.width *= 0.25;
			spr.height *= 0.25;
			spr.x = xx;
			xx = spr.x + spr.width + 10;
			if (i < appids.length - 1){
				var arr = getArrow();
				arr.x = spr.x + spr.width + 10;
				arr.y = Std.int((spr.height - arr.height/2) / 2);
				xx += arr.width/2;
				bcrumbs.addChild(arr);
			}
			bcrumbs.addChild(spr);
		}
		return bcrumbs;
	}
	
	public function onClickBreadcrumb(appid:String){
		
	}
	
	public function rotateVector(x:Float, y:Float, radians:Float):{x:Float, y:Float}
	{
		var cosR = Math.cos(radians);
		var sinR = Math.sin(radians);
		var x2 = x * cosR - y * sinR;
		var y2 = x * sinR + y * cosR;
		return {x:x2, y:y2};
	}
	
	public static function getSquare(w:Int, h:Int, col:Int, transparent:Bool=false):Bitmap
	{
		var bd = new BitmapData(w, h, transparent, col);
		var bmp = new Bitmap(bd);
		bmp.width = w;
		bmp.height = h;
		return bmp;
	}
	
	public function getTooltip()
	{
		var box = getBox(325, 160, 2, 0, 0xFFFFCC);
		var textHeader = Get.text("Header", 15, 0x000000, true);
		var textBody = Get.text("Lorem ipsum dolor sit amet lorem ipsum dolor sit amet lorem ipsum dolor sit amet.", 13, 0x000000, false);
		var tooltip = new Tooltip(box, textHeader, textBody);
		return tooltip;
	}
	
	public static function getBox(w:Int, h:Int, thick:Int, col:Int, ?fill:Int=null)
	{
		var top    = getHLine(w, thick, col);
		var bottom = getHLine(w, thick, col);
		var left   = getVLine(h, thick, col);
		var right  = getVLine(h, thick, col);
		
		top.x = 0;
		top.y = 0;
		bottom.x = 0;
		bottom.y = h - thick;
		
		left.x = 0;
		left.y = 0;
		right.x = w - thick;
		right.y = 0;
		
		var s:Sprite = new Sprite();
		if (fill != null){
			var back = getSquare(w, h, fill);
			s.addChild(back);
		}
		
		s.addChild(top);
		s.addChild(bottom);
		s.addChild(left);
		s.addChild(right);
		return s;
	}
	
	private static function getHLine(length:Int, thick:Int, col:Int):Bitmap
	{
		var bd = new BitmapData(1, 1, false, col);
		var bmp = new Bitmap(bd);
		bmp.width = length;
		bmp.height = thick;
		return bmp;
	}
	
	private static function getVLine(length:Int, thick:Int, col:Int):Bitmap
	{
		var bd = new BitmapData(1, 1, false, col);
		var bmp = new Bitmap(bd);
		bmp.width = thick;
		bmp.height = length;
		return bmp;
	}
	
	var arrowBmp:BitmapData = null;
	private function getArrow():Bitmap
	{
		if (arrowBmp == null){
			arrowBmp = new BitmapData(50, 50, true, 0x00000000);
			var shape:Shape = new Shape();
			
			var sideLength:Float = 16;
			var altitude:Float = Math.sin(Math.PI / 3) * sideLength;
			
			shape.graphics.beginFill(0xFFFFFF);
			shape.graphics.lineTo(0, 0);
			shape.graphics.lineTo(0, sideLength);
			shape.graphics.lineTo(altitude, sideLength / 2);
			shape.graphics.lineTo(0, 0);
			shape.graphics.endFill();
			
			arrowBmp.draw(shape);
		}
		return new Bitmap(arrowBmp);
	}
	
	private function getGridLoc2(i:Int):{x:Float,y:Float}
	{
		return switch(i){
			case 0: {x:-0.5, y:-0.5};
			case 1: {x: 0.0, y:-0.5};
			case 2: {x: 0.5, y:-0.5};
			case 3: {x: 0.5, y: 0.0};
			case 4: {x: 0.5, y: 0.5};
			case 5: {x: 0.0, y: 0.5};
			case 6: {x:-0.5, y: 0.5};
			case 7: {x:-0.5, y: 0.0};
			default:{x:0.0, y:0.0};
		}
	}
	
	private function getGridLoc(i:Int):{x:Float,y:Float}
	{
		return switch(i){
			case 0: {x:0.335, y:0.20};
			case 1: {x:0.665, y:0.20};
			case 2: {x:1.000, y:0.20};
			case 3: {x:1.000, y:0.385};
			case 4: {x:1.000, y:0.570};
			case 5: {x:1.000, y:0.76};
			case 6: {x:0.665, y:0.76};
			case 7: {x:0.335, y:0.76};
			case 8: {x:0.000, y:0.76};
			case 9: {x:0.000, y:0.570};
			case 10:{x:0.000, y:0.385};
			case 11:{x:0.000, y:0.20};
			default:{x:0.000, y:0.20};
		}
	}
}

typedef AppMeta = {
	appid:String,
	score:Float,
	recommender:String
}