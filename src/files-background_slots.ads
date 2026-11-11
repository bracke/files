--  One worker task for slow reads a window asks for and polls: each
--  requester (a window) has one slot, so a newer request of its own replaces
--  an older one not yet started, and one window never cancels another's.
--  There is no cap on requesters: a slot is made for each window that asks
--  and goes when its result is handed out or the window is released, so no
--  number of windows evicts another's request. The worker serves the oldest
--  waiting request first, so no window starves behind one that keeps asking.
--  Quick Look's preview decoding and the info pane's type details use it.
generic
   --  What a request carries besides its path.
   type Parameters is private;
   --  What the work produces.
   type Result is private;
   --  The slow read, run on the worker task. It must not raise; one that
   --  does is answered with Failed.
   with function Work (Path : String; Arguments : Parameters) return Result;
   --  What a raising Work answers.
   with function Failed return Result;
   --  Whether a result is handed out once (a success) or kept and reported
   --  on every Take until the requester asks for something else (a failure,
   --  so the caller does not ask again on every poll).
   with function Handed_Once (Value : Result) return Boolean;
   --  Whether two requests' parameters are the same request: a result read
   --  for other parameters (an older revision of the file) is not handed out
   --  by the Take that names its parameters.
   with function "=" (Left, Right : Parameters) return Boolean is <>;
package Files.Background_Slots is

   --  Who asks: one key per window.
   type Requester is new Natural;

   --  Ask for Path's result for Owner. Replaces Owner's request if the
   --  worker has not started it; returns at once.
   --
   --  @param Owner The window asking.
   --  @param Path The file read.
   --  @param Arguments The rest of the request.
   procedure Request (Owner : Requester; Path : String; Arguments : Parameters);

   --  Owner's result for Path, once the worker has finished it, whatever
   --  parameters it was asked with.
   --
   --  @param Owner The window asking.
   --  @param Path The file it asked about.
   --  @param Value The result when Ready.
   --  @param Ready True when a result for Path was waiting.
   --  @param Asked True when Path is asked for, in work or ready for Owner;
   --    False when the caller must Request it.
   procedure Take
     (Owner : Requester;
      Path  : String;
      Value : out Result;
      Ready : out Boolean;
      Asked : out Boolean);

   --  Owner's result for Path asked with exactly Arguments, once the worker
   --  has finished it. A request of Path with other parameters (read before
   --  the file changed) counts as not asked, and its result is never handed
   --  out here.
   --
   --  @param Owner The window asking.
   --  @param Path The file it asked about.
   --  @param Arguments The parameters the result must have been read with.
   --  @param Value The result when Ready.
   --  @param Ready True when a result for Path and Arguments was waiting.
   --  @param Asked True when Path is asked for with Arguments, in work or
   --    ready for Owner; False when the caller must Request it.
   procedure Take
     (Owner     : Requester;
      Path      : String;
      Arguments : Parameters;
      Value     : out Result;
      Ready     : out Boolean;
      Asked     : out Boolean);

   --  Forget Owner's slot: its request, if not started, is not read, and a
   --  read in work is dropped when it finishes. Called when the window goes.
   --
   --  @param Owner The window going away.
   procedure Release (Owner : Requester);

end Files.Background_Slots;
