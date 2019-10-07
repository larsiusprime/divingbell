package;

/**
 * ...
 * @author 
 */
class Breadcrumb
{
	public var appid:String;
	public var recommendations:MatchResults;
	
	public function new(appid:String, recommendations:MatchResults)
	{
		this.appid = appid;
		this.recommendations = recommendations;
	}
	
}