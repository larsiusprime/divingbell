package;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;

/**
 * ...
 * @author 
 */
class Tooltip
{
	public var sprite:Sprite;
	public var back:Sprite;
	public var header:TextField;
	public var body:TextField;
	
	public function new(back:Sprite, header:TextField, body:TextField) 
	{
		this.sprite = new Sprite();
		
		this.back = back;
		this.header = header;
		this.body = body;
		
		sprite.addChild(back);
		sprite.addChild(header);
		sprite.addChild(body);
		
		header.x = back.x + 7;
		header.y = back.y + 7;
		header.width = back.width - 14;
		
		body.x = back.x + 7;
		body.y = back.y + header.defaultTextFormat.size + 12;
		body.width = back.width - 14;
		body.height = back.height*4;
		body.wordWrap = true;
		body.multiline = true;
	}
	
	public function setText(titleText:String, bodyText:String){
		body.multiline = true;
		header.htmlText = titleText;
		body.htmlText = bodyText;
		var maxHeight =  Math.min((body.y + body.textHeight + 20) - header.y, 900);
		var newBox = Main.getBox(325, Std.int(maxHeight), 2, 0, 0xFFFFCC);
		var backIndex = sprite.getChildIndex(back);
		sprite.removeChild(back);
		sprite.addChildAt(newBox, 0);
		back = newBox;
	}
}