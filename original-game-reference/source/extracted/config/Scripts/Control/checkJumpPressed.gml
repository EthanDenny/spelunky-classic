/* !scriptId=261 */
if (gamepad.jumpPressed)
    return gamepad.jumpPressed;
else
    return (keyboard_check_pressed(global.keyJumpVal));