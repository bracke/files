with Files.Extra_Info;
with Files.Items;

--  The info pane's type details (a text file's lines, a PDF's pages, an
--  archive's entries, a folder's count), read off the UI thread: one could
--  read up to 8 MiB, on every arrow key with the pane open. One worker task
--  reads (Files.Background_Slots), one slot per window.
--
--  A request names the item's revision as well as its path: its kind,
--  filetype, modification time and size as listed. A refresh that relists a
--  rewritten file gives its item a new revision, so a read of the old file
--  still in work is not taken for the new one.
package Files.Extra_Info_Reader is

   --  Who asks: one key per window.
   type Requester is new Natural;

   --  Ask for Item's details for Owner; returns at once.
   --
   --  @param Owner The window asking.
   --  @param Item The selected item, as listed.
   --  @param Show_Hidden Whether the window lists hidden entries: a folder's
   --    count includes them only then.
   procedure Request
     (Owner       : Requester;
      Item        : Files.Items.Directory_Item;
      Show_Hidden : Boolean);

   --  Owner's details of Item, once read for the item as it is listed now.
   --
   --  @param Owner The window asking.
   --  @param Item The item it asked about.
   --  @param Show_Hidden As the request was made with.
   --  @param Extra The details (Files.File_System.Extra_Info_Of) when Ready.
   --  @param Ready True when they were waiting.
   --  @param Asked True when Item, at this revision and with Show_Hidden,
   --    is asked for, being read or ready; False when the caller must
   --    Request it (another file, or this one since changed).
   procedure Take
     (Owner       : Requester;
      Item        : Files.Items.Directory_Item;
      Show_Hidden : Boolean;
      Extra       : out Files.Extra_Info.Info;
      Ready       : out Boolean;
      Asked       : out Boolean);

   --  Forget Owner's request: called when its window goes.
   --
   --  @param Owner The window going away.
   procedure Release (Owner : Requester);

end Files.Extra_Info_Reader;
