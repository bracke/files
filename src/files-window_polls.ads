with Files.Extra_Info_Reader;
with Files.Model;
with Files.Preview_Decoder;

--  What the window loop asks for each pass, beside its input: details,
--  folder sizes and Quick Look images read off the UI thread, handed to the
--  model once they are in. Driven by Files.Application.Windows; nothing here
--  is an operation the user started.
package Files.Window_Polls is

   --  Ensure_Selected_Item_Extra for a window: the details are read by
   --  Files.Extra_Info_Reader's worker, asked for here and taken on a later
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
      Owner       : Files.Extra_Info_Reader.Requester;
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
      Owner : Files.Preview_Decoder.Requester);

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

end Files.Window_Polls;
