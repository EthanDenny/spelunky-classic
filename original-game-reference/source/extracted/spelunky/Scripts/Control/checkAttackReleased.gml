/* !scriptId=285 */
if (gamepad.attackReleased)
    return gamepad.attackReleased;
else
    return (keyboard_check_released(global.keyAttackVal));