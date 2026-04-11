"""
Hetzner Object Storage — S3-compatible cloud storage for media files.
PRD §4.1.8-C: Chat and building operations media uploads.
"""
import os
import uuid
import logging
from datetime import datetime
from typing import Optional

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

logger = logging.getLogger(__name__)

# Environment variables
HETZNER_ACCESS_KEY = os.getenv("HETZNER_ACCESS_KEY", "")
HETZNER_SECRET_KEY = os.getenv("HETZNER_SECRET_KEY", "")
HETZNER_ENDPOINT = os.getenv("HETZNER_ENDPOINT", "https://fra1.digitaloceanspaces.com")  # fallback
HETZNER_BUCKET = os.getenv("HETZNER_BUCKET", "emlakdefter-media")
HETZNER_REGION = os.getenv("HETZNER_REGION", "eu-central")

# CDN base URL (public bucket)
HETZNER_CDN_BASE = os.getenv("HETZNER_CDN_BASE", f"https://{HETZNER_BUCKET}.{HETZNER_ENDPOINT.lstrip('https://')}")


def _get_s3_client():
    """Returns an S3 client configured for Hetzner Object Storage."""
    if not HETZNER_ACCESS_KEY or not HETZNER_SECRET_KEY:
        logger.warning("[Storage] HETZNER credentials not configured — storage will be disabled.")
        return None

    return boto3.client(
        "s3",
        endpoint_url=HETZNER_ENDPOINT,
        aws_access_key_id=HETZNER_ACCESS_KEY,
        aws_secret_access_key=HETZNER_SECRET_KEY,
        region_name=HETZNER_REGION,
        config=Config(signature_version="s3v4"),
    )


def _generate_file_key(filename: str, prefix: str = "media") -> str:
    """Generate a unique S3 key for the file."""
    ext = os.path.splitext(filename)[-1].lower() or ".bin"
    timestamp = datetime.utcnow().strftime("%Y/%m/%d")
    unique_id = uuid.uuid4().hex[:12]
    return f"{prefix}/{timestamp}/{unique_id}{ext}"


async def upload_file(
    file_content: bytes,
    filename: str,
    content_type: str,
    prefix: str = "media",
) -> Optional[str]:
    """
    Upload a file to Hetzner Object Storage.
    Returns the public CDN URL on success, None on failure.
    """
    client = _get_s3_client()
    if client is None:
        logger.warning("[Storage] S3 client unavailable — upload skipped.")
        return None

    key = _generate_file_key(filename, prefix)

    try:
        client.put_object(
            Bucket=HETZNER_BUCKET,
            Key=key,
            Body=file_content,
            ContentType=content_type,
            ACL="public-read",
            Metadata={
                "original-filename": filename,
                "uploaded-at": datetime.utcnow().isoformat(),
            },
        )
        cdn_url = f"{HETZNER_CDN_BASE}/{key}"
        logger.info(f"[Storage] Uploaded: {key} → {cdn_url}")
        return cdn_url
    except ClientError as e:
        logger.error(f"[Storage] Upload failed: {e}")
        return None


async def delete_file(file_key: str) -> bool:
    """Delete a file from Hetzner Object Storage by its key."""
    client = _get_s3_client()
    if client is None:
        return False

    try:
        client.delete_object(Bucket=HETZNER_BUCKET, Key=file_key)
        logger.info(f"[Storage] Deleted: {file_key}")
        return True
    except ClientError as e:
        logger.error(f"[Storage] Delete failed: {e}")
        return False


def generate_presigned_url(key: str, expires_in: int = 3600) -> Optional[str]:
    """
    Generate a presigned URL for private bucket uploads.
    Used for direct browser-to-storage uploads.
    """
    client = _get_s3_client()
    if client is None:
        return None

    try:
        url = client.generate_presigned_url(
            "put_object",
            Params={"Bucket": HETZNER_BUCKET, "Key": key},
            ExpiresIn=expires_in,
        )
        return url
    except ClientError as e:
        logger.error(f"[Storage] Presigned URL generation failed: {e}")
        return None
