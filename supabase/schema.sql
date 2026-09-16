-- ==========================================
-- 1. EXTENSIONS
-- ==========================================
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 2. TABLES
-- ==========================================

-- Users
CREATE TABLE public.users (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  name text NOT NULL,
  email text,
  email_verified timestamp with time zone,
  image text,
  avatar text,
  college text,
  branch text,
  department text,
  bio text,
  contact_info text,
  followers integer DEFAULT 0,
  following integer DEFAULT 0,
  posts_count integer DEFAULT 0,
  saved_count integer DEFAULT 0,
  username text UNIQUE,
  date_of_birth text,
  gender text,
  links text,
  phone text,
  profile_picture text,
  onboarding_complete boolean DEFAULT false,
  notify_likes boolean DEFAULT true,
  notify_comments boolean DEFAULT true,
  notify_mentions boolean DEFAULT true,
  notify_new_posts boolean DEFAULT false,
  role text DEFAULT 'user',
  is_private boolean DEFAULT false,
  comment_privacy text DEFAULT 'Everyone',
  mention_privacy text DEFAULT 'Everyone',
  show_activity_status boolean DEFAULT true,
  last_seen timestamp with time zone DEFAULT now(),
  call_privacy text DEFAULT 'everyone',
  call_quality text DEFAULT 'hd',
  fcm_token text,
  created_at timestamp with time zone DEFAULT now()
);

-- Categories
CREATE TABLE public.categories (
  name text PRIMARY KEY,
  emoji text NOT NULL,
  color text NOT NULL
);

-- Posts
CREATE TABLE public.posts (
  id text PRIMARY KEY,
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  description text NOT NULL,
  content text NOT NULL,
  category text REFERENCES public.categories(name),
  author_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  video_url text,
  image_color text NOT NULL,
  published_at timestamp with time zone DEFAULT now(),
  likes integer DEFAULT 0,
  comments integer DEFAULT 0
);

-- Notifications
CREATE TABLE public.notifications (
  id text PRIMARY KEY,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  type text NOT NULL,
  actor_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  message text NOT NULL,
  time_ago text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  is_read boolean DEFAULT false,
  post_id text REFERENCES public.posts(id) ON DELETE CASCADE
);

-- Announcements
CREATE TABLE public.announcements (
  id text PRIMARY KEY,
  text text NOT NULL,
  type text NOT NULL,
  time_ago text NOT NULL
);

-- Trending Topics
CREATE TABLE public.trending_topics (
  tag text PRIMARY KEY,
  posts_count integer DEFAULT 0
);

-- Conversations
CREATE TABLE public.conversations (
  id text PRIMARY KEY,
  last_message text,
  last_message_time timestamp with time zone,
  unread_count integer DEFAULT 0,
  is_typing boolean DEFAULT false,
  muted boolean DEFAULT false,
  vanish_mode boolean DEFAULT false,
  vanish_duration integer DEFAULT 3600
);

-- Conversation Participants
CREATE TABLE public.conversation_participants (
  conversation_id text REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (conversation_id, user_id)
);

-- Messages
CREATE TABLE public.messages (
  id text PRIMARY KEY,
  conversation_id text REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  text text NOT NULL,
  timestamp timestamp with time zone DEFAULT now(),
  seen boolean DEFAULT false,
  type text NOT NULL,
  reply_to text REFERENCES public.messages(id) ON DELETE SET NULL,
  attachment text,
  expires_at timestamp with time zone,
  is_edited boolean DEFAULT false,
  is_deleted boolean DEFAULT false
);

-- Stories
CREATE TABLE public.stories (
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE PRIMARY KEY,
  seen boolean DEFAULT false
);

-- Story Slides
CREATE TABLE public.story_slides (
  id text PRIMARY KEY,
  story_id uuid REFERENCES public.stories(user_id) ON DELETE CASCADE,
  type text NOT NULL,
  text text,
  emoji text,
  caption text,
  gradient text NOT NULL,
  media_url text,
  timestamp timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now()
);

-- Story Views
CREATE TABLE public.story_views (
  story_id uuid REFERENCES public.stories(user_id) ON DELETE CASCADE,
  viewer_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  reaction text,
  PRIMARY KEY (story_id, viewer_id)
);

-- Post Likes
CREATE TABLE public.post_likes (
  post_id text REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, user_id)
);

-- Post Comments
CREATE TABLE public.post_comments (
  id text PRIMARY KEY,
  post_id text REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  text text NOT NULL,
  parent_id text REFERENCES public.post_comments(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now()
);

-- Comment Likes
CREATE TABLE public.comment_likes (
  comment_id text REFERENCES public.post_comments(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (comment_id, user_id)
);

-- Post Saves
CREATE TABLE public.post_saves (
  post_id text REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  PRIMARY KEY (post_id, user_id)
);

-- User Blocks
CREATE TABLE public.user_blocks (
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  blocked_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  PRIMARY KEY (user_id, blocked_id)
);

-- User Mutes
CREATE TABLE public.user_mutes (
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  muted_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  PRIMARY KEY (user_id, muted_id)
);

-- User Reports
CREATE TABLE public.user_reports (
  id text PRIMARY KEY,
  reporter_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  target_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  reason text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- Post Reports
CREATE TABLE public.post_reports (
  id text PRIMARY KEY,
  reporter_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  post_id text REFERENCES public.posts(id) ON DELETE CASCADE,
  reason text NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);

-- Follows
CREATE TABLE public.follows (
  follower_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  following_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now(),
  PRIMARY KEY (follower_id, following_id)
);

-- Follow Requests
CREATE TABLE public.follow_requests (
  id text PRIMARY KEY,
  follower_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  following_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT now()
);

-- Feedback
CREATE TABLE public.feedback (
  id text PRIMARY KEY,
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  type text NOT NULL,
  message text NOT NULL,
  reply text,
  created_at timestamp with time zone DEFAULT now()
);

-- ==========================================
-- 3. SUPABASE AUTH TRIGGER
-- ==========================================
-- Automatically create a user in public.users when a user signs up via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, name, email, avatar)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'New User'),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$;

-- Trigger the function every time a user is created
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ==========================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

-- Enable RLS on core tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_saves ENABLE ROW LEVEL SECURITY;

-- USERS Table
CREATE POLICY "Profiles are viewable by everyone." 
  ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile." 
  ON public.users FOR UPDATE USING (auth.uid() = id);

-- POSTS Table
CREATE POLICY "Posts are viewable by everyone." 
  ON public.posts FOR SELECT USING (true);
CREATE POLICY "Users can insert their own posts." 
  ON public.posts FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Users can update own posts." 
  ON public.posts FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "Users can delete own posts." 
  ON public.posts FOR DELETE USING (auth.uid() = author_id);

-- CONVERSATIONS & MESSAGES (Secure Chat)
CREATE POLICY "Users can view their conversations" 
  ON public.conversation_participants FOR SELECT USING (auth.uid() = user_id);
  
CREATE POLICY "Users can see messages in their conversations" 
  ON public.messages FOR SELECT USING (
    conversation_id IN (
      SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can send messages to their conversations" 
  ON public.messages FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND
    conversation_id IN (
      SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
    )
  );

-- NOTIFICATIONS
CREATE POLICY "Users can view own notifications." 
  ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications." 
  ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own notifications." 
  ON public.notifications FOR DELETE USING (auth.uid() = user_id);

-- LIKES & COMMENTS
CREATE POLICY "Everyone can see likes and comments" 
  ON public.post_likes FOR SELECT USING (true);
CREATE POLICY "Users can like posts" 
  ON public.post_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike posts" 
  ON public.post_likes FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Everyone can see comments" 
  ON public.post_comments FOR SELECT USING (true);
CREATE POLICY "Users can comment on posts" 
  ON public.post_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own comments" 
  ON public.post_comments FOR DELETE USING (auth.uid() = user_id);

-- FOLLOWS
CREATE POLICY "Everyone can see follows" 
  ON public.follows FOR SELECT USING (true);
CREATE POLICY "Users can follow others" 
  ON public.follows FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can unfollow others" 
  ON public.follows FOR DELETE USING (auth.uid() = follower_id);

-- ==========================================
-- 5. REMAINING RLS POLICIES (Stories, Saves, Reports)
-- ==========================================

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trending_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_mutes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follow_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- Public Read-Only Tables
CREATE POLICY "Categories viewable by everyone" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Announcements viewable by everyone" ON public.announcements FOR SELECT USING (true);
CREATE POLICY "Trending topics viewable by everyone" ON public.trending_topics FOR SELECT USING (true);

-- Post Saves (Private to the user)
CREATE POLICY "Users can view own saves" ON public.post_saves FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own saves" ON public.post_saves FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own saves" ON public.post_saves FOR DELETE USING (auth.uid() = user_id);

-- Comment Likes
CREATE POLICY "Everyone can view comment likes" ON public.comment_likes FOR SELECT USING (true);
CREATE POLICY "Users can like comments" ON public.comment_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike comments" ON public.comment_likes FOR DELETE USING (auth.uid() = user_id);

-- Stories & Slides
CREATE POLICY "Stories viewable by everyone" ON public.stories FOR SELECT USING (true);
CREATE POLICY "Users can insert own stories" ON public.stories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Story slides viewable by everyone" ON public.story_slides FOR SELECT USING (true);
CREATE POLICY "Users can insert own slides" ON public.story_slides FOR INSERT WITH CHECK (auth.uid() = story_id);

-- Follow Requests
CREATE POLICY "Users can view own requests" ON public.follow_requests FOR SELECT USING (auth.uid() = follower_id OR auth.uid() = following_id);
CREATE POLICY "Users can send requests" ON public.follow_requests FOR INSERT WITH CHECK (auth.uid() = follower_id);
CREATE POLICY "Users can delete requests" ON public.follow_requests FOR DELETE USING (auth.uid() = follower_id OR auth.uid() = following_id);

-- Moderation & Feedback (Insert Only for users)
CREATE POLICY "Users can insert reports" ON public.user_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Users can insert post reports" ON public.post_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Users can insert feedback" ON public.feedback FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view own blocks" ON public.user_blocks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can block" ON public.user_blocks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can view own mutes" ON public.user_mutes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can mute" ON public.user_mutes FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ==========================================
-- 6. REALTIME CONFIGURATION
-- ==========================================
-- Enable Realtime for the 'messages' table so the Flutter client can listen for new messages via .stream()
alter publication supabase_realtime add table messages;
