with Files.Types;

--  The info pane's type details (a text file's lines, a PDF's pages, an
--  archive's entries, a folder's count), read off the UI thread: one could
--  read up to 8 MiB, on every arrow key with the pane open. One worker task
--  reads (Files.Background_Slots), one slot per window.
package Files.Extra_Info_Reader is

   --  Who asks: one key per window.
   type Requester is new Natural;

   --  Ask for Path's details for Owner; returns at once.
   --
   --  @param Owner The window asking.
   --  @param Path The selected item.
   --  @param Kind Its kind.
   --  @param Filetype Its detected filetype.
   procedure Request
     (Owner    : Requester;
      Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String);

   --  Owner's details of Path, once read.
   --
   --  @param Owner The window asking.
   --  @param Path The item it asked about.
   --  @param Token The details (Files.File_System.Extra_Info_Token) when Ready.
   --  @param Ready True when they were waiting.
   --  @param Asked True when Path is asked for, being read or ready; False
   --    when the caller must Request it.
   procedure Take
     (Owner : Requester;
      Path  : String;
      Token : out Files.Types.UString;
      Ready : out Boolean;
      Asked : out Boolean);

end Files.Extra_Info_Reader;
