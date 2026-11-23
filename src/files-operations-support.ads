with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Model;
with Files.Settings;
with Files.UI_Types;

--  Internal helpers shared by the Files.Operations subunits (one per operation).
--  A private child so only the Files.Operations hierarchy can see it; the public
--  Operation_Result/Operation_Status types come from the parent spec.
private package Files.Operations.Support is

   --  The empty open action (no executable, no arguments), used as the default
   --  Action for results that do not launch anything.
   --
   --  @return An open action with an empty executable and no arguments.
   function Empty_Action return Files.Settings.Open_Action;

   --  The first leaf name of Base, Marker (First), Marker (First + 1), ...
   --  and Extension that names nothing in Directory: how a duplicate, a
   --  link, an archive or an extracted folder finds its name
   --  (Files.Leaf_Names.First_Free, cut to what Directory's filesystem
   --  stores, the marker and the extension kept whole). Raises Use_Error
   --  when a name cannot be looked at (Fs_Primitives.Is_Taken) or none of
   --  Leaf_Names.Max_Attempts is free: never a name that may be in use.
   --
   --  @param Directory Where the new entry goes.
   --  @param Base The stem the names start from.
   --  @param Extension Its extension, without the dot, or "".
   --  @param Marker What follows Base for an attempt (" (copy 2)", "").
   --  @param First The first attempt (0 where the bare name comes first).
   --  @param Attempt An attempt number.
   --  @return The free leaf name.
   function First_Free_Leaf
     (Directory : String;
      Base      : String;
      Extension : String;
      Marker    : not null access function (Attempt : Natural) return String;
      First     : Natural := 1)
      return String;

   --  Construct an Operation_Result, folding an open action's fields into the
   --  flat result record.
   --
   --  @param Status Operation status to report.
   --  @param Error_Key Localisation key for an error, or "" when none.
   --  @param Path Path the result refers to, or "" when none.
   --  @param Action Open action whose fields are folded into the result.
   --  @param Attempted Whether a launch was attempted.
   --  @param Found Whether the executable was found.
   --  @param Exit_Known Whether an exit status is known.
   --  @param Exit_Status The child exit status when known.
   --  @return The assembled operation result.
   function Make_Result
     (Status      : Operation_Status;
      Error_Key   : String := "";
      Path        : String := "";
      Action      : Files.Settings.Open_Action := Empty_Action;
      Attempted   : Boolean := False;
      Found       : Boolean := False;
      Exit_Known  : Boolean := False;
      Exit_Status : Integer := 0)
      return Operation_Result;

   --  Set the model error and return a disabled result for a command that is not
   --  currently applicable.
   --
   --  @param Model Window model whose error state is set.
   --  @param Error_Key Localisation key for the disabled reason.
   --  @return A disabled operation result carrying Error_Key.
   function Disabled
     (Model     : in out Files.Model.Window_Model;
      Error_Key : String)
      return Operation_Result;

   --  At least one real item is selected, by the rule the command catalog
   --  states (Commands.Status_Of's Real_Selection) and with its messages:
   --  nothing selected, or a pending create row that has no file behind it.
   --
   --  @param Model Window model holding the selection.
   --  @return Disabled with that message, or Operation_Success.
   function Real_Selection_Refusal (Model : in out Files.Model.Window_Model) return Operation_Result;

   --  Reload the model's current directory, optionally selecting Select_Name or
   --  restoring the complete current selection, and refresh its signature.
   --  Search results are searched again instead, in the same scope, so an
   --  operation run on them leaves them shown, brought up to date; their
   --  names are not unique, so they keep the selection by path, and only
   --  Select_Path picks an item among them.
   --
   --  @param Model Window model whose current directory is reloaded.
   --  @param Settings Settings model used to classify the reload.
   --  @param Select_Name Item name to re-select after reload, or "" for none.
   --  @param Preserve_Selection Restore all current selected paths when no
   --    Select_Name is supplied.
   --  @param Select_Path Full path of the item to select, winning over
   --    Select_Name: an item an operation made beside its source, which is
   --    selected where the reloaded view lists it and nowhere else.
   --  @return Success result, or a failed result when the reload fails.
   function Reload_Current_Directory
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Select_Name : String := "";
      Preserve_Selection : Boolean := False;
      Select_Path : String := "")
      return Operation_Result;

   --  Whether Reload_Current_Directory hands the reload to a background
   --  read (which keeps the error set before it) rather than reloading
   --  here (which clears it): in a window, whose transfers run in helpers.
   --  Search results are searched again either way (Files.Refresh.Start's
   --  Search_Again), never replaced by the folder's listing.
   --
   --  @param Model Window model to inspect.
   --  @return True when the next reload runs in the background.
   function Reloads_In_Background (Model : Files.Model.Window_Model) return Boolean;

   --  Replace the view with the recursive search results for the filter
   --  text below the current folder, in Scope (Navigation.Run_Search, which
   --  refuses first, says what is shown).
   --
   --  @param Model Window model containing the current path and filter query.
   --  @param Settings Settings model used for classification.
   --  @param Scope Search by name or by content.
   --  @return Structured operation result.
   function Search_Current_Folder
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Scope    : Files.UI_Types.Tree_Search_Scope)
      return Operation_Result;

   --  A batch (duplicate, extract, links) stopped by a failure: when some
   --  of it was already written the listing is reloaded so that output shows
   --  (and the error survives the reload), otherwise only the error is set.
   --  @param Model Window that ran the batch.
   --  @param Settings Directory settings for the reload.
   --  @param Error_Key The failure reported.
   --  @param Directory The directory the result names.
   --  @param Wrote_Some Whether earlier items of the batch were written.
   --  @return The failed result.
   function Batch_Failed
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Error_Key  : String;
      Directory  : String;
      Wrote_Some : Boolean)
      return Operation_Result;

   --  Finalize an operation error before scheduling its reload: the error
   --  is what the operation reports, whatever the reload does.
   --  @param Model Window whose error and listing to update.
   --  @param Settings Directory settings for the reload.
   --  @param Error_Key Operation error to preserve through completion.
   --  @param Path The path the error's message names, or "" when none.
   procedure Reload_With_Error
     (Model : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Error_Key : String;
      Path : String := "");

   --  Load the folder at Path to show it: listed with Settings'
   --  classification and listing options, its new images' thumbnails left
   --  to a background listing (Load_Directory_Deferring_Thumbnails). The
   --  one load every view change and in-place reload makes.
   --
   --  @param Settings Directory settings.
   --  @param Path Absolute folder path.
   --  @return The listing, or why it failed.
   function Load_Folder
     (Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Files.File_System.Directory_Load_Result;

   --  What every folder loaded to show (Load_Folder) ends with, once the
   --  caller has installed Load's items (navigated, committed the typed
   --  path, started a window, or replaced them in place): the trash flag
   --  settled when the view moved to another folder, the signature the
   --  watch compares with stored, the error line cleared, and the images
   --  still lacking a thumbnail owed to a background listing
   --  (Files.Model.Note_Owed_Refresh, which the window's poll pays through
   --  Files.Refresh.Resume_Owed), so nothing waits on decoding.
   --
   --  @param Model Window that now shows Load's items.
   --  @param Load The listing installed.
   --  @param Moved The view moved to another folder (False for a reload).
   procedure Show_Loaded_Folder
     (Model : in out Files.Model.Window_Model;
      Load  : Files.File_System.Directory_Load_Result;
      Moved : Boolean := True);

   --  Put a staged file or folder at Target, as Files.File_System.Transfer.Publish_Staged
   --  does: never over an entry already there, flushed before and named
   --  after, intended and recorded as created. The one way Compress and
   --  Extract publish what they made.
   --
   --  @param Staged The finished file or folder inside a stage.
   --  @param Target Where it is published.
   --  @param Identity Set to its identity token, for its Undo.
   --  @param Revision Set to its tree revision, for its Undo.
   --  @return False when it was not published; Staged is then left for the
   --    caller to discard with its stage.
   function Publish_Staged
     (Staged   : String;
      Target   : String;
      Identity : out Ada.Strings.Unbounded.Unbounded_String;
      Revision : out Ada.Strings.Unbounded.Unbounded_String)
      return Boolean;

   --  Remove an operation's private stage (Files.Jobs.Context.Discard_Stage);
   --  a removal that fails is traced with its path, and leaves the stage
   --  for the job scavenger.
   --  @param Stage The stage directory.
   procedure Discard_Stage (Stage : String);

   --  @param Path Entry to test.
   --  @return True when Path is inside a trash's files folder.
   function Is_Trash_Child (Path : String) return Boolean;

end Files.Operations.Support;
