# CAT Controller
CAT Controller: an adaptable, easy to configure 3rd person character controller with semi-custom mover
constraints based physics.

### Features:

- Custom state machine based physics simulation
- Character- and physics models are compltely decoupled from one another -> collision bounding boxes 
do not depend on the visible character model
- Easy to replace character models via drag and drop
- Easy to configure and replace animations with the Animation module
- Full mobile support
- Integrated visual debug features

### TODO:
- Console support
- Integrated, switchable nametag system
- Configurable amount of emote animations with assignable keybindings and integrated, switchable UI
- Health system with death animations
- (Configurable in-game settings interface)
- (Custom inventory / backpack implementation)

## Build Process:
Clone the repository:
```bash
git clone https://github.com/BrickEngine/cat-controller.git
```

### Dependencies: 
The following dependencies are required to build the project:
- Latest version of [Rojo](https://github.com/rojo-rbx/rojo)

### Final steps:
Generate a .rbxlx file:
```bash
cd <path/to/cat-controller/dir>
rojo build -o "CatController.rbxlx"
```

Open the generated place file in Roblox Studio.