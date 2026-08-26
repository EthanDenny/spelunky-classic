/* !scriptId=286 */
if (gamepad.payPressed)
    return gamepad.payPressed;
else
    return (keyboard_check_pressed(global.keyPayVal));