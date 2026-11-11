with Files.Items;
with Files.Model;
with Files.Settings;

--  Internal helpers shared by the Files.Operations subunits (one per operation).
--  A private child so only the Files.Operations hierarchy can see it; the public
--  Operation_Result/Operation_Status types come from the parent spec.
private package Files.Operations.Support is

   --  The empty open action (no executable, no arguments), used as the default
   --  Action for results that do not launch anything.
   --
   --  @return An open action with an empty executable and no arguments.
   function Empty_Action return Files.Settings.Open_Action;

   --  Ada.Directories.Exists raises Name_Error on a malformed path rather than
   --  returning False; this treats any failure as "does not exist" so it cannot
   --  escape an operation as an unhandled exception.
   --
   --  @param Path Filesystem path to test.
   --  @return True when Path exists, False when it does not or the test failed.
   function Exists_Safely (Path : String) return Boolean;

   --  How many numbered names (" 2", " (copy 3)") a new entry tries before
   --  giving up on a free one.
   Max_Name_Attempts : constant := 9_999;

   --  The first stem of Base & Marker (First), Base & Marker (First + 1),
   --  ... (up to Max_Name_Attempts) that names nothing in Directory, with
   --  Extension ("" for none), or the first one when all are taken: how a
   --  duplicate, a link, an archive or an extracted folder finds its name.
   --  Base is cut at a whole character where the name would otherwise be
   --  longer than Directory's filesystem stores; the marker and the
   --  extension are kept whole.
   --  @param Directory Where the new entry goes.
   --  @param Base The stem the names start from.
   --  @param Extension Its extension, without the dot.
   --  @param Marker What follows Base for an attempt (" (copy 2)", "").
   --  @param First The first attempt (0 where the bare name comes first).
   --  @param Attempt An attempt number.
   --  @return The free stem.
   function First_Free_Name
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

   --  Whether Executable names something this host will actually run: an
   --  on-PATH command, or a path that is a regular executable file.
   --
   --  @param Executable Executable name to look up, or a path to a file.
   --  @return True when it resolves to a runnable executable.
   function Executable_Is_Available (Executable : String) return Boolean;

   --  Reload the model's current directory, optionally selecting Select_Name or
   --  restoring the complete current selection, and refresh its signature.
   --
   --  @param Model Window model whose current directory is reloaded.
   --  @param Settings Settings model used to classify the reload.
   --  @param Select_Name Item name to re-select after reload, or "" for none.
   --  @param Preserve_Selection Restore all current selected paths when no
   --    Select_Name is supplied.
   --  @return Success result, or a failed result when the reload fails.
   function Reload_Current_Directory
     (Model       : in out Files.Model.Window_Model;
      Settings    : Files.Settings.Settings_Model;
      Select_Name : String := "";
      Preserve_Selection : Boolean := False)
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

   --  A listing loaded with Load_Directory_Deferring_Thumbnails: when an
   --  image in it still lacks a thumbnail, start the background listing
   --  that makes them, so the window never waits on decoding.
   --  @param Model Window that shows Items.
   --  @param Settings Directory settings for the background listing.
   --  @param Items The listing just shown.
   procedure Generate_Missing_Thumbnails
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Items    : Files.Items.Item_Vectors.Vector);

end Files.Operations.Support;
