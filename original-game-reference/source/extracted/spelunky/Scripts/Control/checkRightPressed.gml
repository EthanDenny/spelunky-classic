/* !scriptId=266 */
if (gamepad.rightPressed)
    return gamepad.rightPressed;
else
    return (keyboard_check_pressed(global.keyRightVal));