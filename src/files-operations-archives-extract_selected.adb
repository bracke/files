with Files.Items;
with Files.File_Types;
with Files.Name_Parts;
with Files.Protocol_Names;

separate (Files.Operations.Archives)
function Extract_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items     : constant Files.Items.Item_Vectors.Vector :=
     Files.Model.Selection.Selected_Items (Model);
   Directory : constant String := Files.Model.Current_Path (Model);

   First_Created : Unbounded_String;
   Extracted_Any : Boolean := False;
   --  The extracted folders (From).
   Progress      : Progressive_Undo :=
     (Kind => Files.Undo.History.Undo_Delete_Created, Redoable => False, others => <>);

   --  An earlier archive in the same batch may already have committed.
   --  Keep that output visible as well as undoable, while preserving the
   --  diagnostic which explains why the remaining batch stopped.
   --  An entry it cannot extract, named in the message.
   Refused_Key : constant String := "error.extract.entry_refused";

   function Failed (Key : String := "error.extract.failed") return Operation_Result is
   begin
      Finish_Failed_Undo (Model, Progress);
      return Batch_Failed (Model, Settings, Key, Directory, Wrote_Some => not Progress.Items.Is_Empty);
   end Failed;

   --  The message for an archive zlib would not read or extract: what the
   --  user can act on (a password, a damaged or unsupported archive), else
   --  the general one. The status itself is traced with the archive.
   function Failed (Archive : String; Status : Zlib.Status_Code) return Operation_Result is
   begin
      Files.Diagnostics.Trace ("Files.Operations", "extract_status=" & Status'Image & ",archive=" & Archive);
      return Failed
        (case Status is
            when Zlib.Password_Required | Zlib.Invalid_Password => "error.extract.encrypted",
            when Zlib.Unsupported_Method | Zlib.Unsupported_Preset_Dictionary => "error.extract.unsupported",
            when Zlib.Invalid_Header | Zlib.Invalid_Checksum | Zlib.Invalid_Block_Type | Zlib.Invalid_Stored_Block
               | Zlib.Invalid_Huffman_Code | Zlib.Invalid_Distance | Zlib.Unexpected_End_Of_Input =>
               "error.extract.damaged",
            when Zlib.Ok | Zlib.Input_File_Error | Zlib.Output_File_Error | Zlib.Insufficient_Memory
               | Zlib.Cancelled =>
               "error.extract.failed");
   end Failed;

   --  Extract one selected item beside it, if it is an archive: into a stage
   --  first, then published as a directory-unique folder named after it,
   --  recorded for Undo. Stop is True when the batch ends here, with Result
   --  its outcome: an entry that cannot be extracted (named in the message),
   --  limits the volume cannot hold, or a failed extraction or publish.
   procedure Extract_One
     (Item   : Files.Items.Directory_Item;
      Stop   : out Boolean;
      Result : out Operation_Result)
   is separate;
begin
   declare
      Refusal : constant Operation_Result := Creation_Refusal (Model, "error.extract.failed");
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   if Items.Is_Empty then
      return Failed;
   end if;

   for Item of Items loop
      exit when Files.Jobs.Context.Cancelled;
      declare
         Stop   : Boolean;
         Result : Operation_Result;
      begin
         Extract_One (Item, Stop, Result);
         if Stop then
            return Result;
         end if;
      end;
   end loop;
   declare
      Undo : constant Undo_Outcome := Finish_Undo (Model, Progress);
   begin
      if not Extracted_Any then
         return Failed;
      end if;

      --  Reload so the new directories appear, and select the first one.
      declare
         Result : constant Operation_Result := Reload_Current_Directory (Model, Settings, To_String (First_Created));
      begin
         Note_Undo_Outcome (Model, Undo, Result);
         return Result;
      end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return Failed;
end Extract_Selected;
