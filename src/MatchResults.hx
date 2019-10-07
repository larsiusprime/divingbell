package;

/**
 * ...
 * @author 
 */
class MatchResults
{
	public var appids:Array<String>;
	public var scores:Array<Float>;
	public var metas:Array<String>;
	
	public function new(appids:Array<String>=null, scores:Array<Float>=null, metas:Array<String>=null) 
	{
		this.appids = appids;
		this.scores = scores;
		this.metas = metas;
		if (this.appids == null){
			this.appids = [];
		}
		if (this.scores == null){
			this.scores = [];
			for (i in 0...this.appids.length){
				this.scores.push(0.0);
			}
		}
		if (this.metas == null){
			this.metas = [];
			for (i in 0...this.appids.length){
				this.metas.push("");
			}
		}
	}
	
	public function clear()
	{
		appids = [];
		scores = [];
		metas  = [];
	}
	
	public function toString():String
	{
		return "MatchResults:\n->appids=" + appids + "\n->scores=" + scores + "\n->metas=" + metas;
	}
	
	public function concat(mr:MatchResults):MatchResults
	{
		appids = appids.concat(mr.appids.copy());
		scores = scores.concat(mr.scores.copy());
		metas = metas.concat(mr.metas.copy());
		return this;
	}
	
	public function copy():MatchResults{
		var mr = new MatchResults();
		mr.appids = appids.copy();
		mr.scores = scores.copy();
		mr.metas = metas.copy();
		return mr;
	}
	
	public function add(appid:String, score:Float, meta:String="")
	{
		appids.push(appid);
		scores.push(score);
		metas.push(meta);
	}
	
	public function shift():{appid:String, score:Float, meta:String}
	{
		var appid = appids.shift();
		var score = scores.shift();
		var meta = metas.shift();
		if (appid == null && score == null && meta == null) return null;
		return {appid:appid, score:score, meta:meta};
	}
}