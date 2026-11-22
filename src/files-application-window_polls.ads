with Files.Application.Extra_Info_Reader;
with Files.Model;
with Files.Application.Preview_Decoder;

--  What the shown window needs read for it beside its input: details,
--  folder sizes and Quick Look images, read off the UI thread and handed to
--  the model once they are in (or, with no helpers, read at once), and the
--  volume's free space and the info pane's account names, sampled before a
--  frame is drawn. Driven by the window loop and by what changes the
--  selection; nothing here is an operation the user started.
package Files.Application.Window_Polls is

   --  Ensure_Selected_Item_Extra for a window: the details are read by
   --  Files.Application.Extra_Info_Reader's worker, asked for here and taken on a later
   --  poll once read.
   --
   --  The request names the item's revision, so details read for a file
   --  since rewritten and relisted are not applied to the new item.
   --
   --  @param Model Window model whose selected item is updated in place.
   --  @param Owner Which window asks (one read in flight per window).
   --  @param Show_Hidden Whether the window shows hidden entries
   --    (Settings.Show_Hidden_Files): a folder's count includes them only
   --    then. True, for a caller without settings, counts every entry.
   procedure Poll_Selected_Item_Extra
     (Model       : in out Files.Model.Window_Model;
      Owner       : Files.Application.Extra_Info_Reader.Requester;
      Show_Hidden : Boolean := True);

   --  Publish the folder sizes the window's measurement helper has finished,
   --  for its current selection, after letting it make progress.
   --
   --  @param Model Window model whose measurements to poll.
   procedure Poll_Folder_Sizes (Model : in out Files.Model.Window_Model);

   --  Hand the open Quick Look preview its decoded image once the decoder
   --  has it (Prepare_Quick_Look asked for it).
   --
   --  @param Model Window model whose preview to complete.
   --  @param Owner Which window asks (one decode in flight per window).
   procedure Poll_Quick_Look
     (Model : in out Files.Model.Window_Model;
      Owner : Files.Application.Preview_Decoder.Requester);

   --  Stop the window's folder-size measurement and discard what it had not
   --  yet published.
   --
   --  @param Model Window model whose measurements to cancel.
   procedure Cancel_Folder_Scan (Model : in out Files.Model.Window_Model);

   --  Refresh the cached recursive folder size for the current selection.
   --
   --  Request uncached selected directories from a helper process and prune
   --  stale cached totals. The frame loop publishes completed measurements for
   --  the info pane and selection total. Never traverses directories here.
   --
   --  @param Model Window model whose folder-size cache is updated.
   procedure Update_Folder_Size (Model : in out Files.Model.Window_Model);

   --  Sample the current directory's volume space into Model when its last
   --  sample is stale (Files.Model.Status_Samples.Volume_Space_Is_Current),
   --  so the snapshot shows it without querying the disk itself.
   --
   --  @param Model Window model whose current directory is sampled.
   procedure Sample_Volume_Space
     (Model : in out Files.Model.Window_Model);

   --  Sample what the host offers (a trash folder, permission and ownership
   --  editing) into Model when its last sample is stale
   --  (Files.Model.Status_Samples.Host_Is_Current), so the commands' status
   --  and the snapshot read it without asking the host on every build.
   --
   --  @param Model Window model to sample for.
   procedure Sample_Host
     (Model : in out Files.Model.Window_Model);

   --  Resolve the owner and group names of the items the info pane lists into
   --  Model (Files.Model.Status_Samples.Set_Account_Name), so the snapshot
   --  shows names without an NSS lookup of its own. Does nothing while the
   --  model is unchanged since the last sample, or when the info pane shows
   --  no item.
   --
   --  @param Model Window model whose info-pane items are sampled.
   procedure Sample_Account_Names
     (Model : in out Files.Model.Window_Model);

end Files.Application.Window_Polls;
