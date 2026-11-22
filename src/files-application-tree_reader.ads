with Files.File_System;
with Files.File_Types;
with Files.Types;

--  The folder tree's children, read off the UI thread: expanding a node over
--  a folder of 20,000 subfolders held the window for tens of milliseconds,
--  seconds on a network share. One worker task reads
--  (Files.Application.Background_Slots), one slot per window; the window
--  polls (Files.Application.Window_Polls.Poll_Tree_Children).
package Files.Application.Tree_Reader is

   --  Who asks: one key per window.
   type Requester is new Natural;

   --  Ask for Path's subdirectories for Owner
   --  (Files.File_System.Load_Subdirectories); returns at once.
   --
   --  @param Owner The window asking.
   --  @param Path The folder whose children are read.
   --  @param Classes How subfolders are classified (for a sort by type).
   --  @param Options Hidden-entry and sort policy.
   procedure Request
     (Owner   : Requester;
      Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options);

   --  Owner's read of Path, once done with exactly these Classes and
   --  Options.
   --
   --  @param Owner The window asking.
   --  @param Path The folder it asked about.
   --  @param Classes As the request was made with.
   --  @param Options As the request was made with.
   --  @param Load The read when Ready.
   --  @param Ready True when it was waiting.
   --  @param Asked True when Path is asked for with these, being read or
   --    ready; False when the caller must Request it.
   procedure Take
     (Owner   : Requester;
      Path    : String;
      Classes : Files.File_Types.Classification;
      Options : Files.Types.Listing_Options;
      Load    : out Files.File_System.Directory_Load_Result;
      Ready   : out Boolean;
      Asked   : out Boolean);

   --  Forget Owner's request: called when its window goes.
   --
   --  @param Owner The window going away.
   procedure Release (Owner : Requester);

end Files.Application.Tree_Reader;
