with Ada.Directories;
with Ada.Strings.Unbounded;
with Ada.Streams.Stream_IO;
with Files.Durable_Writes;
with Hostkit.Fs;

package body Files.Copy_Context is
   use Ada.Strings.Unbounded;
   function Create return Session is
      Result : Session;
   begin
      Files.Process_Jobs.Reserve (Result.Job);
      return Result;
   end Create;

   function Directory (Batch : Session) return String is
     (if Length (Batch.Borrowed) > 0 then To_String (Batch.Borrowed)
      else Files.Process_Jobs.Path (Batch.Job, ""));

   function Borrow (Path : String) return Session is
     ((Job => <>, Borrowed => To_Unbounded_String (Path)));

   function Records (Batch : Session) return Files.Types.String_Vectors.Vector is
      File : Ada.Streams.Stream_IO.File_Type;
      Result : Files.Types.String_Vectors.Vector;
      Path : constant String := (if Directory (Batch) = "" then "" else Hostkit.Fs.Join (Directory (Batch), "links"));
   begin
      if Path = "" or else not Ada.Directories.Exists (Path) then
         return Result;
      end if;
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Result := Files.Types.String_Vectors.Vector'Input (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      return Result;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Records;

   procedure Save (Batch : Session; Items : Files.Types.String_Vectors.Vector) is
      File : Ada.Streams.Stream_IO.File_Type;
      Path : constant String := (if Directory (Batch) = "" then "" else Hostkit.Fs.Join (Directory (Batch), "links"));
      Temp : constant String :=
        (if Directory (Batch) = "" then "" else Hostkit.Fs.Join (Directory (Batch), "links.tmp"));
   begin
      if Path = "" then
         return;
      end if;
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Temp);
      Files.Types.String_Vectors.Vector'Output (Ada.Streams.Stream_IO.Stream (File), Items);
      Ada.Streams.Stream_IO.Close (File);
      if not Files.Durable_Writes.Published
        (Files.Durable_Writes.Publish (Temp, Path))
      then
         raise Ada.Directories.Use_Error;
      end if;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Save;
end Files.Copy_Context;
