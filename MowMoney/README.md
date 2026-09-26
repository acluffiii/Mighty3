# Mow Money

A top-down lawn mowing game. Open `index.html` in any browser (phone or desktop). It needs no build step and has no dependencies other than Google Fonts.

## Core loop

1. **Mow a customer's lawn.** Each square foot you cut pays out. Cash pops up as you go.
2. **Chain combos.** Keep cutting fresh grass without a break to build up to a x5 multiplier. Driving over grass you've already cut drains the combo.
3. **Earn stars.** Each of these earns a star, and each star adds to your tip:
   - beat par time
   - leave the flower beds intact
   - mow straight stripes (at least 70% of neighboring cells cut in the same direction)
4. **Spend it in the Garage.** Buy engine, blade and pay upgrades, then save up for bigger mowers: Push Mower, then Lawn Tractor, Zero-Turn and Mega Deck.
5. **Take bigger jobs.** Each job is a larger yard with more obstacles: driveways, trees, flower islands, gnomes, rocks, then pools.

Extras:
- Golden dandelions are hidden in the grass and pay bonus cash.
- Power-ups: Turbo, Wide deck and Double pay.
- A pointer arrow and highlighted patches help you find the last uncut grass.

## Controls

- **Touch or mouse:** drag anywhere to use the floating joystick.
- **Keyboard:** WASD or arrow keys. Esc or P pauses.

Progress is saved in the browser's `localStorage`.
