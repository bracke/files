with Files.Images;

--  Quick Look's full-size preview, decoded off the UI thread. A camera
--  photo took 50 to 300 ms to read and decode, and moving through a folder
--  with Quick Look open paid that on every key. One worker task decodes;
--  each requester (a window) has one slot, so a newer request of its own
--  replaces an older one not yet started, and one window never cancels
--  another's.
package Files.Preview_Decoder is

   --  Who asks: one key per window.
   type Requester is new Natural;

   --  Ask for Path decoded to fit within Size x Size for Owner. Replaces
   --  Owner's request if the worker has not started it; returns at once.
   --
   --  @param Owner The window asking.
   --  @param Path Image file.
   --  @param Size Longest side of the decoded preview.
   procedure Request (Owner : Requester; Path : String; Size : Positive);

   --  Owner's decoded preview of Path, once the worker has finished it.
   --  Each result is handed out once.
   --
   --  @param Owner The window asking.
   --  @param Path The file it previews.
   --  @param Image The decoded preview when Ready (Available False when the
   --    file could not be decoded).
   --  @param Ready True when a result for Path was waiting.
   --  @param Asked True when Path is asked for, decoding or ready for Owner;
   --    False when the caller must Request it.
   procedure Take
     (Owner : Requester;
      Path  : String;
      Image : out Files.Images.Decoded_Image;
      Ready : out Boolean;
      Asked : out Boolean);

end Files.Preview_Decoder;
