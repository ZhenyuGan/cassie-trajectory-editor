
# Cassie Trajectory Tool


This tool runs on top of the the simulation program, [MuJoCo](http://www.mujoco.org/), and is designed to generate and modify walking trajectories for the bipedal robot, [Cassie](http://www.agilityrobotics.com/robots/).
The generated walking trajectories can act as the reference motion in [reinforcement learning](https://arxiv.org/abs/1803.05580) so varied walking behaviors can be learned on Cassie.


This tool was developed [Kevin Kellar](https://github.com/kkevlar) and with the mentorship of [Patrick Clary](https://github.com/pclary) for use within the [Dynamic Robotics Laboratory](http://mime.oregonstate.edu/research/drl/) at Oregon State University.

# Getting Started 

## Getting Started: Compilation / Dependencies

1. Clone
2. Add a [MuJoCo key](https://www.roboti.us/license.html) to the repository root directory and name it mjkey.txt
3. Install `libglfw3-dev` and `wget`
4. `make`

## Compilation: Troubleshooting

Error | Solution
--- | ---
"MuJoCo will need a product key to run the tool. Please provide a product key for MuJoCo and name it mjkey.txt." | The makefile will terminate compilation if mjkey.txt is not in the root repository directory. Please [provide this file](https://www.roboti.us/license.html).


# Development: ToDo's

## Primary 

* [ ] select change single joint
* [ ] one-sided scaling transformation
* [ ] Variable node count


* [ ] Add user controls with respect to initialization
  * [ ] Allow different trajectories to be loaded in
  * [ ] Add control over loop number
  * [ ] Allow for initialization with a single pose
* [ ] Export trajectories in the same format as the input file
* [ ] Allow for "clipping" of larger trajectory
* [ ] Fix undos/redos/overwrites so it doesn't leak memory
* [ ] Document the current controls
* [ ] Make ctrl p respect the different pert types
* [ ] Look into drag files into MuJoCo window
* [ ] ghost nodes when dragging to show starting positions
* [ ] Different color nodes for different transformation methods




# Controls


## Initialization



## "Old" Commands


### "New" Commands

Input Command | Context | Effect
--- | --- | ---
Ctrl+Z | Any | Undo a trajectory modification. Will reset the timeline to its complete previous state. An 'Undo' can be redone with 'Redo'
Ctrl+Y or Ctrl+Shift+Z | Any | Redo a trajectory modification
Ctrl+P | Any | Load a perturbation from the configuration file at last.pert; In the current implementation, any perturbation with the mouse overwrites this file
Ctrl+R | See note below* | Refines a completed modification. Uses the list of frame/xpos target pairs saved after every call to `node_perform_pert()`, and will re-run IK on each target with a smaller error cutoff. Can be undone with the Undo command
Ctrl+E | Any | 'Expands' the current pose. The resulting timeline (undo-able) will have the same length and number of poses as the previous timeline, but will be filled with the current pose (except xpos[0], which is copied over)
Space | Any | Toggles pause for trajectory playback. When paused the camera may still be moved, bodies can be selected, nodes can be perturbed, IK will still be solved, Undo/Redo/LoadPert/Refine/Expand will all still work
Right Arrow | Any | Will step the trajectory time forward by some arbitrary step size. This step is in relation to visualization time, not number of frames although this may change in the future
Left Arrow | Any | Will step back by the step size
Up Arrow | Any | Will step forward by 10x the step size
Down Arrow | Any | Will step back by 10x the step size
Ctrl+Scroll | Not dragging a node | Works the same as Left/Right Arrows but for Up/Down scroll wheel
Ctrl+Scroll | Dragging a node | Scales the standard deviation of the trajectory perturbation. Scrolling up will increase the standard deviation and will smooth the perturbation over more nearby frames, while a scroll down will do the opposite
Ctrl+Shift+Scroll | Dragging a node | Scales the 'height' of the [Gaussian distribution](https://en.wikipedia.org/wiki/Normal_distribution) that is used to smooth perturbations. Height defaults at 1 and will not go lower than 1, but an increased height will cause nearby nodes to be transformed as much as the root node of the perturbation. Often used in combination with a 'target' perturbation command to hold the body in the same place for a number of frames


\*Refine-Command Context Note: Every time  calls the [IK solver](https://github.com/osudrl/cassie-trajectory-editor/blob/docs/WRITEUP.md#inverse-kinematics), it saves a list of frame/xpos targets for the refiner function to use. Any time IK is solved, this target list is overwritten, however, this target list is not with respect to the timeline, just the last time IK was run. This may be improved in the future, but at the moment, all refine commands must directly follow a previous refine command or a node-drag-perturbation.


# Tool Source Documentation


The following sections discuss the code base of the tool.


## Big Picture: Roadmap Diagram


![rough roadmap diagram](https://i.imgur.com/hGbAoiS.png)

The above diagram identifies many of the key source files, data structures, and fucntions of the tool.

Symbol | Description
--- | ---
Rectangle (solid outline) | Function
Rectangle (dashed outline) | Data structure
Solid Arrow | Connects function caller (base) to callee (tip)
Number on Arrow | Identifies the order that the caller calls these functions
Dashed Arrow | Data accesses and overwrites
Dashed Fence | The files (.c/.h) where these functions/structures are sourced
Diamond | Confusing decision points within functions
Circle | Distinct tasks within a method


The diagram is most useful when used in conjunction with the written description of each feature.


## Important Data Structures

Each major data structure is explained below

Sub-Heading | Information
--- | ----
Memory Location | Where in memory does this data actually live? Stack frame, globals, heap, etc.
Setup | How and where is structure is initially set up
Usages | Relevant times the structure is used in functions
Fields | List of contained fields, ordered from most to least relevant

### traj_info_t ([Definition](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/main.h#L53:L69))

The traj_info struct initially was defined just to encapsulate the [mjModel\*](http://www.mujoco.org/book/reference.html#mjModel) / [mjData\*](http://www.mujoco.org/book/reference.html#mjData) references such that method calls had the ability to modify the robot's qpos values. Now, however, the struct has expanded to hold all the current runtime information about the tool, including the pose timeline and other common structures used by MuJoCo method calls.

#### Memory Location

The traj_info struct is allocated as a global [towards the top of simulate.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/simulate.c#L135:L152), and is passed to all functions as a pointer to this definition.

#### Setup

The struct is initially set up by [simulate.c : reset_traj_info()](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/simulate.c#L135:L152) which is called by [simulate.c : loadmodel()](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/simulate.c#L534:L584).

#### Usages

Nearly ever function of the tool takes a traj_info reference because it allows access to the the timeline of poses and allows helper functions to modify the model's joint angles, external forces, etc.

#### Fields

Type / Name | Description | Initial State | Used In
--- | --- | --- | ---
[mjModel\*](http://www.mujoco.org/book/reference.html#mjModel) m | Contains the information about the simulated Cassie model | Initialized in `reset_traj_info()` with the value set by `load_model()` | When making calls to MuJoCo functions such as `mj_foward()` and `mj_step()` 
[mjData\*](http://www.mujoco.org/book/reference.html#mjData) d | Contains runtime physics data, such as joint positions, forces, and velocities | Same as above | Same as above
bool* paused | A reference to the paused variable in simulate.c's globals | Same as above | Used in [main_traj.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/main-traj.c#L49:L63) to calculate the runtime of the visualization
[mjvPerturb\*](http://www.mujoco.org/book/reference.html#mjvPerturb) pert | A reference to struct allocated in simulate.c's globals, containing data about the user dragging and dropping bodies (not anymore) with Ctrl+RightMouse  / nodes | Initialized in `reset_traj_info()`. Always points to the same structure allocated in globals | By `main-traj.c : allow_node_transformations()` to update the dragged node's position to match the mouse's position
[timeline_t\*](https://github.com/osudrl/cassie-trajectory-editor#timeline_t-definition) timeline | A struct listing each discrete pose throughout the step duration | Initialized in timeline.c | Most of the timeline.c functions use this field for setting / overwriting poses
pdikdata_t ik | A struct containing the parameters for solving IK using the [MuJoCo control function callback](http://www.mujoco.org/book/reference.html#mjcb_control) | In [ik.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/ik.c#L128:L133) | Used to control the pdik solver in [pdik.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/pdik.c#L21:L40)
~double nodesigma~ | ~The relative standard deviation of the Gaussian filter used to smooth translations~ | ~Same as above~ | ~Used in the node.c module to apply smoothed translations and determine the "cutoff" for the Gaussian filter~


### pdikdata_t ([Definition](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/pdik.h#L11:L24))


#### Memory Location


Stored within the traj_info struct.


#### Setup


Set up mostly in [ik.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/ik.c#L128:L133) and a bit in [simulate.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/simulate.c#L146:L147)


#### Usages


Used in [pdik.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/pdik.c#L21:L40) to perform PD-based IK through the [MuJoCo control function callback](http://www.mujoco.org/book/reference.html#mjcb_control).


#### Fields


Type / Name | Description | Initial State | Used In
--- | --- | --- | ---
int body_id | The body id on Cassie which is being manipulated | Set in ik.c using the function argument passed through by `nodeframe_ik_transform` in node.c | Used in pdik.c, defining to which body the pdik controller is applied
double target_body[3] | The xyz coordinates which are the target for the IK to be solved | Same as above | Used in `apply_pd_controller()` in pdik.c as the target for the PD controller
double lowscore | The smallest "error" from the body's position to the target position so far | Initially set as a large value so that it is set to the actual error after a single step of pdik | Used in ik.c to decide when to stop iterating to solve IK
double pd_k | The 'spring constant', which is the coefficient for the P (positional) term for the pd controller | Set in [ik.c](https://github.com/osudrl/cassie-trajectory-editor/blob/5d9722b7fdfb91c40a43e6a97ea7320624ed869f/src/ik.c#L67:L82) | Used in `apply_pd_controller()` to scale the positional term
double pd_b | The 'damping constant', which is the coefficient for the D (derivative) term for the pd controller | Same as above | Used in `apply_pd_controller()` to scale the derivative term
int32_t max_doik | Controls the maximum number of steps for the IK solver before it will be forced to give up | Set in ik.c to the value of the [count parameter](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/ik.c#L128) which is passed by the `nodeframe_ik_transform()` function in [node.c](https://github.com/osudrl/cassie-trajectory-editor/blob/0dbf44c7536c35cd1c7d0dfab21b6e0a6ace8941/src/node.c#L89:L95) | Used to set the initial value of doik (see below)
int32_t doik | Controls the number of steps of IK that the solver will do. | Initially set to the value of max_doik in ik.c during the pdikdata struct setup | Used in the `pdik_per_step_control()` function, as it will only perform IK while this value is a positive number. Decrements this number every simulation step.


### timeline_t ([Definition](https://github.com/osudrl/cassie-trajectory-editor/blob/v0.1/src/main.h#L16:L27))


#### Memory Location



#### Setup



#### Usages


#### Fields


### selection_t


#### Memory Location



#### Setup



#### Usages


#### Fields

## Node.c Module


The functions within the node module implements a few different types and specific vector math.
These functions are core the the functionality of the tool, but are long and unwieldy.

### Node Module Specific Types

**v3_t** is defined in node.h, and adds a bit more specificity than "double\*" when dealing with 3d vectors.
Although `v3_t` and `double\*` are literally interchangeable, this type should only be used when requiring a vector of length 3.
Functions with v3_t as a parameter will expect to be able to index the array at v[0], v[1], and v[2] and that these values should be the x, y and z values of the specified vector.

**cassie_body_t** and **node_body_t** do not provide any more information than an int.
Yet wrapping these ints in a struct provides strong type checking, preventing the functions which use these types from mistakenly interchanging these two different types.
Furthermore, the function prototypes in the header are able to clearly communicate what kind of body (cassie or node) is needed for the calculations.
To revert this type checking, all uses of these types can be replaced with unsigned ints, and the functions for wrapping the ids can be deleted.

### Node Module Functions of Interest

#### node_get_body_id_from_node_index()

**Definition:**
```c
node_body_id_t node_get_body_id_from_node_index(int index);
```

**Returns** a `node_body_id` type corrosponding to the **index** provided

Assumptions: Acceptible node indecies are in the range [0,199]: at the moment, cassie.xml defines 200 node bodies

**No changes to current qposes**

**No changes to any timeline**





# Contact


This tool and documentation page was written by [Kevin Kellar](https://github.com/kkevlar) for use within the [Dynamic Robotics Laboratory](http://mime.oregonstate.edu/research/drl/) at Oregon State University.
For issues, comments, or suggestions about the tool or its documentation, feel free to [contact me](https://github.com/kkevlar) or [open a GitHub issue](https://github.com/osudrl/cassie-trajectory-editor/issues).


