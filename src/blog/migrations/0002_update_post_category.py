from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('blog', '0001_initial'),
    ]

    operations = [
        # Match the database field to the current Post model.
        migrations.AlterField(
            model_name='post',
            name='category',
            field=models.CharField(
                choices=[
                    ('e', 'Entertainment'),
                    ('m', 'Music'),
                    ('i', 'IT'),
                ],
                default='e',
                max_length=15,
            ),
        ),
        migrations.DeleteModel(
            name='Category',
        ),
    ]