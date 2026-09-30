class_name ParkedBot
extends BotBase
## Negative control (D-056, D-122): walks from the night-1 start to home (0, 9.5) and stays there.

func think(_delta: float) -> void:
	go_to("home")
