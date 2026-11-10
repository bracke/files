with Ada.Strings.Unbounded;

with Files.Types;

--  The extra line the info pane shows for an item -- a folder's item count, a
--  document's pages, a text file's lines and encoding, a link's target -- as
--  data. File_System reads it, the model keeps it, the job records carry it,
--  and only the renderer turns it into words; no field is ever split out of a
--  string again (a target or a name may hold any character).
package Files.Extra_Info is

   type Kind is
     (None,
      Directory_Count,
      --  Count direct items; Capped when the count stopped at its limit.
      Executable_Format,
      --  Value: elf, pe, script or unknown.
      Symlink_Target,
      --  Value: the target as stored.
      Text_Lines,
      --  Subject: text, markdown, source.ada, source.json or source.xml;
      --  Count lines; Value the encoding (ascii, utf8, binary ...).
      Image_Dimensions,
      --  Value: "W x H" as Dimensions_Text writes it.
      Document_Kind,
      --  Value: the document family (pdf).
      Pdf_Pages,
      --  Count page markers.
      Archive_Format,
      --  Value: tar or gzip.
      Archive_Entries,
      --  Subject: zip; Count entries.
      Office_Entries,
      --  Subject: docx or xlsx; Count package entries.
      Media_Kind);
      --  Value: audio or video.

   type Info is record
      Of_Kind : Kind := None;
      Count   : Natural := 0;
      Capped  : Boolean := False;
      Subject : Files.Types.UString;
      Value   : Files.Types.UString;
   end record;

   No_Info : constant Info := (others => <>);

   --  An Info of Of_Kind with the fields that kind uses.
   --
   --  @param Of_Kind What the line says.
   --  @param Subject The kind's subject (see Kind).
   --  @param Value The kind's value (see Kind).
   --  @param Count The kind's count (see Kind).
   --  @param Capped Whether the count stopped at its limit.
   --  @return The extra info.
   function Make
     (Of_Kind : Kind;
      Subject : String := "";
      Value   : String := "";
      Count   : Natural := 0;
      Capped  : Boolean := False)
      return Info is
     (Of_Kind => Of_Kind,
      Count   => Count,
      Capped  => Capped,
      Subject => Ada.Strings.Unbounded.To_Unbounded_String (Subject),
      Value   => Ada.Strings.Unbounded.To_Unbounded_String (Value));

end Files.Extra_Info;
