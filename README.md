### ICPipeline Worker

This module contains a Dockerfile and its companion *setup.sh*, which together comprise the Docker image for your containerized *ICPipeline Workers*.

![icpipeline-workerdocker-overview.png](https://icpipeline.com/media/documentation/icpipeline-workerdocker-overview.png)
<p align="center" style="color:gray;font-size:14px;"> <b>Figure 3: ICPipeline Worker (Docker) Overview</b> </p>

Each *ICPipeline Worker* is on an Ubuntu Linux base, additionally running:

- *Node/NPM*
- *Git*
- The *Dfinity Canister SDK* (aka *DFX*)
- The ICPipeline *Uplink* communications/orchestration module
- a few *other helpful items*
  
Each *Worker* is a complete IC replica and collaborative DFX workstation that (unlike your laptop) is fully *network-available*.  Think *IC* QA, without the shoulder surfing.

Use any *Worker* as:
  - a deployment tasker (managed from your ICPM, so you may never need to log into it)
  - a network-available hosting platform for your *dev* and *QA* deployments
    - (*stage* and *prod* Environments deploy to the mainnet IC)
  - a collaborative dfx/Node workstation
  - a replica backend host for *Internet Identity* project integrations [Workers that are "*II-enabled*"] 
  
  ...or as any combination of the above.  Workers are generic, identical at birth.  Each one is basically an Ubuntu "box" with the tools preloaded.  Each Worker auto-registers with its designated ICPipeline Manager (ICPM) d'app.  Just `docker run` however Workers many you need, and use your ICPM dashboard to run your fleet.


### What Makes a Worker a Worker?
Any machine running ICPipeline's *Uplink* module is effectively a Worker, taskable by a Pipeline Manager (ICPM) d'app on the Internet Computer.  *Uplink* is the NodeJS application that coordinates the action between each Worker and its designated ICPM mothership.  Every Worker, as part of its bootstrap sequence, retrieves the current *Uplink* code base from GitHub, and kicks it off as a perpetual system process.  While running, *Uplink* "phones home" continually on a 20-second polling interval.  It first registers the new Worker with its ICPM (by canister ID, which is dynamically implanted in the Docker image).  Once registered it continues polling, for the Worker's pairing with an Environment.  Once paired-up, it begins polling for work assignments.  The Worker executes the tasks it is assigned (aka *Jobs* in ICPM), delivering near-real-time activity logs back to the Pipeline Manager dashboard.  Complete *Uplink* source code (*uplink.js*) is in the *Manager/ICPM* submodule of the top-level ICPipeline repository, sibling to this *Worker* module.  The *ICPM* module has its own README, which contains more detail about ICPM and its usage.

To be sure, **there's no reason why a Worker *must* be a Docker**.  Any Unix box, virtual or otherwise, can theoretically achieve greatness as an ICPipeline Worker.  This is interesting in a broader sense too, i.e. to consider basically any W2 host, doing basically anything, directly tasked by/from the blockchain.  It seems that no-brainer use cases would be all over the map.  In any case, containers are a great fit in this case.  You can spin them up, and just as easily discard them like, well, like Dockers.  Workers generally don't hold sole copies of any asset\*.  If you can see the appeal of a *networked* environment that allows you to be more *fearless* with your pre-prod IC projects, this framework may work very well for you.

\* One caveat, relating to code/asset changes made directly on a Worker (that works great, BTW):  in that instance, those particular changes would exist solely on the Worker -- just until you `git push` them, directly from the Worker.  In this respect, a Worker is like any other workstation; just so we're clear about that.

#### Building the Image
We anticipate and intend that most users will start with the ICPipeline Installer.  The installer builds the entire, working ICPipeline framework from scratch, with this Worker submodule as one of its components.

However, the Worker Docker will *docker build* (or *buildx*) anywhere the tools are available.

To *docker build* Workers independently from the ICPipeline installer:

- Verify that the Dockerfile and *setup.sh* are residing in the same directory.

- Note that the *Worker* Dockerfile takes a ```BUILD_ARG``` of ```ICPW_USER_PW```.  That is required even if you choose to disable password authentication on your Workers (which we strongly suggest).  Of course, if you *do* allow password auth, then please choose a good one, you know the drill.  The installer only enforces a minimum length, so you can opt for convenience in environments that are externally secured.  But, if you're going to enable password auth at all in situations where it actually counts, please use something long and randomized.  It's dark out there, and only getting darker.

```
docker build -t --build-arg ICPW_USER_PW=<your-password> <your-imagename> <your-context>
```
Or *docker buildx build* if you require or prefer *BuildKit*:

```
docker buildx build --build-arg ICPW_USER_PW=<your-password> ...
```
This is the password for the *icpipeline* system user on each Worker, with full (passwordless) sudo su privileges.  *icpipeline@...* is the default login account on each Worker, if you need or wish to use it.  As referenced in the top-level README, *icpipeline* is more than a power-user admin account.  Scaling back system permissions for this account will, in all likelihood, cause things to break.

#### Running Containers from the Image
Likewise, any container you `docker run` *from* a Worker image -- via Docker Dashboard, ECS, Kubernetes or howsoever -- will fetch and launch *Uplink* on bootup, register with ICPM and begin polling for assignments (assuming there's network connectivity with its designated ICPM). 



#### Architectural Things Worth Noting
We made choices with respect to the overall architecture of the framework.  Those choices can matter, in various ways big and small, so we'll share some important ones here.

**Your Workers and the Canister SDK**
The Canister SDK (dfx) is *not* compiled into your ICPipeline Docker image by default.  Rather, SDK installation is located in the Dockerfile's *setup.sh*.  So the SDK is freshly fetched and installed on each individual Worker container at runtime.  There is the obvious reason, i.e. so that SDK versioning takes care of itself, with each container having the current version installed.\*\*

Another aspect of this approach (which we also like) pertains to DFX and *Identity*.  Because each Worker will `dfx start` the SDK for what is truly the first time, each Worker gets a clean slate in the  `dfx identity` layer, with its own `default`, and so forth.  Put a pin in this, we'll return to it after we provide some context.

[BTW THIS PART IS IMPORTANT, and your ICPM module README has the unabridged version]

Each *Environment* added to ICPM goes in one of four main *categories* (these are standard *CI/CD* vocab, as you can see):
- **dev**
- **QA**
- **stage**
- **prod**

**All *dev* and *QA* Environments will deploy "locally"** (i.e. without `network ic` in the dfx command).

**All *stage* and *prod* Environments will deploy to the mainnet IC** (i.e. *with* `network ic` in the dfx command).

A Worker will adhere to the settings of its assigned Environment/Project.  ICPM has robust tools for managing Identities, Canister profiles, Principals, etc., as they pertain to *mainnet* IC deployments.  For local deployments (again, in your *dev* and *QA* Environments) we take a more "vanilla" approach for simplicity's sake.  We are aware that use cases exist where even local deployments won't *always* be vanilla.  We look forward to feedback from the dev community as we refine/enhance going forward.


\*\* We considered that corner-case snags might arise, relating to SDK versions and backwards compatibility.  But putting the SDK in the image wouldn't solve those anyway.  If your IC project is hard-coded for a legacy SDK version (full disclosure, this is not a road we've actually been down), it should be manageable with a tweak to *setup.sh* (in your Worker submodule alongside the Dockerfile).


#### Security and General Tech Notes
Note that each *run* of the ICPipeline installer generates a new RSA *client* key pair.  And each individual Worker container will generate its own unique *hostkeys* key pair.  The public key from the client key pair is baked into your Worker Docker image.  Any container you `docker run` subsequently from this image will accept the same client key -- having that *public* key in its *authorized_keys* config file.  The takeaway here is that *you and your team can share the SSH key, and it works on all your Workers* (just your Workers, not anyone else's).  And there's no cross-sharing of host keys between Workers in your fleet.  Sorry this is dense.  Just share the SSH key among the team, and you're good to go ;)

For example: let's say you're using your container orchestration platform to spin up some additional Workers under your existing Pipeline Manager d'app (this is a perfectly good approach).  Each such container, at birth, will automatically register with that Manager; and each one will be ssh-accessible via the private key from that same key pair.

#### FYI re: Versioning
This is open-source software, which anyone may freely adapt and modify, so it is included in this repository package.  However, please be aware that the ICPipeline installer re-clones this submodule at runtime from GitHub.  So, depending on how long you wait between cloning and installing, it is possible that your local copy of this code *might* lag a commit or two behind the version that's actually deployed to your running Workers.  While submodules can be cloned individually, we highly suggest keeping your versions in-sync for most predictable outcomes.  This is early-lifecycle software, being delivered by a small team, and the modules are highly interdependent.  And, if this roadmap has a speed limit, we have not seen it yet.

#### Just Our Little Speech, About Securing Your Workers
As mentioned elsewhere, we think remote password authentication should *always* be disabled, on any Linux box.

Not to jump into the weeds, but, if you DO decide to enable password auth: password *length* is your best friend (along with sheer randomness).  Each character you add increases a dictionary cracker's number of possible wrong guesses by another *power* (exponent); by adding length, you are logarithmically frustrating bad actors.  We do only enforce a minimum 6-char length, which is us just trying to be practical.  For particular cases where this layer may not actually need to be airtight, it's an opportunity for us to reduce onboarding friction, which is important to us.  And you know what you're doing anyway.  But if your ICPipeline is compromised, that's bad a day for us too.  And the whole blockchain/crypto space has too many contrarians, all of whom are, as it seems, the chatty type.


The ICPipeline team is available for support.