package;

/**
 * ...
 * @author 
 */
class Util
{

	public static function shuffle(a:Array<String>){
		for (k in 1...a.length){
		   var i = (a.length - k);
		   var j = Std.int(Math.random() * i);
		   var temp = a[j];
		   a[j] = a[i];
		   a[i] = temp;
	   }
	}
}