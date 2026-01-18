import json
import os
import torch
import numpy as np
from PIL import Image

class HowlerInputCanvas:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {},
            "optional": {
                "force_reload": ("BOOLEAN", {"default": False, "label_on": "Reload", "label_off": "Cached"}),
            }
        }
    
    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("image",)
    FUNCTION = "load_canvas"
    CATEGORY = "PD Howler"
    
    @classmethod
    def IS_CHANGED(cls, force_reload=False):
        json_path = r"B:\PD HOWLER\DOGEXCHANGE\Dog_send\Dog_send_canvas\canvas_data.json"
        if os.path.exists(json_path):
            mtime = os.path.getmtime(json_path)
            if force_reload:
                import time
                return f"{mtime}_{time.time()}"
            return mtime
        return float("nan")
    
    def load_canvas(self, force_reload=False):
        json_path = r"B:\PD HOWLER\DOGEXCHANGE\Dog_send\Dog_send_canvas\canvas_data.json"
        
        print(f"[Howler Input] Looking for: {json_path}")
        
        if not os.path.exists(json_path):
            print(f"[Howler Input] ERROR: Canvas data not found!")
            dummy = torch.zeros((1, 64, 64, 3))
            return (dummy,)
        
        file_size = os.path.getsize(json_path) / (1024 * 1024)
        print(f"[Howler Input] Found file: {file_size:.2f} MB")
        
        try:
            print("[Howler Input] Loading JSON...")
            with open(json_path, 'r') as f:
                data = json.load(f)
            
            print("[Howler Input] JSON loaded successfully")
            
            width = data.get('width')
            height = data.get('height')
            pixels = data.get('pixels')
            
            if not width or not height or not pixels:
                print(f"[Howler Input] ERROR: Missing data - width:{width}, height:{height}, pixels:{len(pixels) if pixels else 0}")
                dummy = torch.zeros((1, 64, 64, 3))
                return (dummy,)
            
            print(f"[Howler Input] Image dimensions: {width}x{height}, pixel count: {len(pixels)}")
            
            image_array = np.array(pixels, dtype=np.float32)
            print(f"[Howler Input] Array shape before reshape: {image_array.shape}")
            
            image_array = image_array.reshape((height, width, 3))
            print(f"[Howler Input] Array shape after reshape: {image_array.shape}")
            
            image_tensor = torch.from_numpy(image_array).unsqueeze(0)
            print(f"[Howler Input] Final tensor shape: {image_tensor.shape}")
            
            print(f"[Howler Input] ✓ SUCCESS! Loaded canvas: {width}x{height}")
            return (image_tensor,)
            
        except json.JSONDecodeError as e:
            print(f"[Howler Input] ERROR: JSON decode failed: {e}")
            dummy = torch.zeros((1, 64, 64, 3))
            return (dummy,)
        except Exception as e:
            print(f"[Howler Input] ERROR: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            dummy = torch.zeros((1, 64, 64, 3))
            return (dummy,)


class HowlerInputAnimation:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "start_frame": ("INT", {"default": 0, "min": 0, "max": 9999}),
                "frame_count": ("INT", {"default": 10, "min": 1, "max": 9999}),
            },
            "optional": {
                "force_reload": ("BOOLEAN", {"default": False, "label_on": "Reload", "label_off": "Cached"}),
            }
        }
    
    RETURN_TYPES = ("IMAGE",)
    RETURN_NAMES = ("images",)
    FUNCTION = "load_animation"
    CATEGORY = "PD Howler"
    
    @classmethod
    def IS_CHANGED(cls, start_frame, frame_count, force_reload=False):
        base_path = r"B:\PD HOWLER\DOGEXCHANGE\Dog_send\Dog_send_anim_buffer"
        
        max_mtime = 0
        for frame_num in range(start_frame, start_frame + frame_count):
            frame_filename = f"frame_{frame_num:04d}.json"
            frame_path = os.path.join(base_path, frame_filename)
            
            if os.path.exists(frame_path):
                mtime = os.path.getmtime(frame_path)
                max_mtime = max(max_mtime, mtime)
        
        if force_reload and max_mtime > 0:
            import time
            return f"{max_mtime}_{time.time()}"
        
        return max_mtime if max_mtime > 0 else float("nan")
    
    def load_animation(self, start_frame, frame_count, force_reload=False):
        base_path = r"B:\PD HOWLER\DOGEXCHANGE\Dog_send\Dog_send_anim_buffer"
        
        frames = []
        
        for frame_num in range(start_frame, start_frame + frame_count):
            frame_filename = f"frame_{frame_num:04d}.json"
            frame_path = os.path.join(base_path, frame_filename)
            
            if not os.path.exists(frame_path):
                print(f"[Howler Input] WARNING: Frame {frame_num} not found, stopping")
                break
            
            try:
                with open(frame_path, 'r') as f:
                    data = json.load(f)
                
                width = data['width']
                height = data['height']
                pixels = data['pixels']
                
                image_array = np.array(pixels, dtype=np.float32)
                image_array = image_array.reshape((height, width, 3))
                
                frames.append(image_array)
                
            except Exception as e:
                print(f"[Howler Input] ERROR loading frame {frame_num}: {e}")
                break
        
        if len(frames) == 0:
            print("[Howler Input] No frames loaded!")
            dummy = torch.zeros((1, 64, 64, 3))
            return (dummy,)
        
        frames_tensor = torch.from_numpy(np.array(frames))
        
        print(f"[Howler Input] Loaded {len(frames)} animation frames")
        return (frames_tensor,)


class HowlerOutputCanvas:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "images": ("IMAGE",),
            }
        }
    
    RETURN_TYPES = ()
    OUTPUT_NODE = True
    FUNCTION = "save_canvas"
    CATEGORY = "PD Howler"
    
    def save_canvas(self, images):
        output_path = r"B:\PD HOWLER\DOGEXCHANGE\Dog_recieve\Dog_rec_canvas\result_canvas.json"
        
        print(f"[Howler Output] Input tensor shape: {images.shape}")
        print(f"[Howler Output] Input tensor type: {type(images)}")
        
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        # Handle batch dimension
        if len(images.shape) == 4:
            image = images[0]  # Take first image from batch
        else:
            image = images
        
        print(f"[Howler Output] Image shape after batch handling: {image.shape}")
        
        # Convert to numpy if needed
        if isinstance(image, torch.Tensor):
            image = image.cpu().numpy()
        
        # Ensure we have (height, width, 3) shape
        if len(image.shape) != 3 or image.shape[2] != 3:
            print(f"[Howler Output] ERROR: Unexpected shape {image.shape}, expected (H, W, 3)")
            return {}
        
        height, width, channels = image.shape
        print(f"[Howler Output] Final dimensions: {width}x{height}x{channels}")
        
        # Flatten to list of [r,g,b] pixels
        pixels = image.reshape(-1, 3).tolist()
        
        print(f"[Howler Output] Pixel count: {len(pixels)}")
        print(f"[Howler Output] Sample pixel: {pixels[0]}")
        
        result_data = {
            "width": width,
            "height": height,
            "format": "rgb_normalized",
            "pixels": pixels
        }
        
        try:
            print("[Howler Output] Writing JSON...")
            with open(output_path, 'w') as f:
                json.dump(result_data, f)
            
            file_size = os.path.getsize(output_path) / (1024 * 1024)
            print(f"[Howler Output] ✓ SUCCESS! Saved canvas: {width}x{height} ({file_size:.2f} MB)")
            print(f"[Howler Output] Location: {output_path}")
            return {}
            
        except Exception as e:
            print(f"[Howler Output] ERROR saving canvas: {e}")
            import traceback
            traceback.print_exc()
            return {}


class HowlerOutputAnimation:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "images": ("IMAGE",),
            }
        }
    
    RETURN_TYPES = ()
    OUTPUT_NODE = True
    FUNCTION = "save_animation"
    CATEGORY = "PD Howler"
    
    def save_animation(self, images):
        output_dir = r"B:\PD HOWLER\DOGEXCHANGE\Dog_recieve\Dog_rec_anim_buffer"
        
        os.makedirs(output_dir, exist_ok=True)
        
        existing_files = [f for f in os.listdir(output_dir) if f.startswith("result_") and f.endswith(".json")]
        for f in existing_files:
            os.remove(os.path.join(output_dir, f))
        
        if isinstance(images, torch.Tensor):
            images = images.cpu().numpy()
        
        num_frames = images.shape[0]
        
        for frame_num in range(num_frames):
            frame = images[frame_num]
            height, width, channels = frame.shape
            
            pixels = frame.reshape(-1, 3).tolist()
            
            frame_data = {
                "frame": frame_num,
                "width": width,
                "height": height,
                "format": "rgb_normalized",
                "pixels": pixels
            }
            
            frame_filename = f"result_{frame_num:04d}.json"
            frame_path = os.path.join(output_dir, frame_filename)
            
            try:
                with open(frame_path, 'w') as f:
                    json.dump(frame_data, f)
                
            except Exception as e:
                print(f"[Howler Output] ERROR saving frame {frame_num}: {e}")
        
        print(f"[Howler Output] Saved {num_frames} animation frames to {output_dir}")
        return {}


NODE_CLASS_MAPPINGS = {
    "HowlerInputCanvas": HowlerInputCanvas,
    "HowlerInputAnimation": HowlerInputAnimation,
    "HowlerOutputCanvas": HowlerOutputCanvas,
    "HowlerOutputAnimation": HowlerOutputAnimation,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "HowlerInputCanvas": "Howler Input (Canvas)",
    "HowlerInputAnimation": "Howler Input (Animation)",
    "HowlerOutputCanvas": "Howler Output (Canvas)",
    "HowlerOutputAnimation": "Howler Output (Animation)",
}
