--  One worker task for slow reads a window asks for and polls: each
--  requester (a window) has one slot, so a newer request of its own replaces
--  an older one not yet started, and one window never cancels another's.
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

   --  Owner's result for Path, once the worker has finished it.
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

end Files.Background_Slots;
